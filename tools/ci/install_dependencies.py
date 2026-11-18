#!/usr/bin/env python3
"""Bounded CI dependency setup using official Ubuntu HTTPS mirrors on GitHub.

GitHub Actions Ubuntu runners with a regular mirrorlist use official HTTPS on
the first attempt. Supported Ubuntu24.04 sources are isolated from unrelated
runner feeds during system setup; other environments retain normal sources. System
dependencies and browser download each have their own bounded deadline.
Playwright's public install-deps then
install commands retain the same dependencies and host validation as --with-deps;
neither GPG/TLS nor host checks are disabled. Temporary APT settings are restored
before browser download. No repository setting, publisher or credential changes.
"""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

# apt-transport-mirror requires a TAB before metadata. A space becomes part of
# the URI and produces HTTP400 once DNS succeeds; keep this actual APT-tested.
OFFICIAL_MIRRORS="https://archive.ubuntu.com/ubuntu\tpriority:1\nhttps://security.ubuntu.com/ubuntu\tpriority:2\n"
APT_LIMITS='Acquire::Retries "2";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\nAPT::Update::Error-Mode "any";\n'
UBUNTU_KEYRING=Path('/usr/share/keyrings/ubuntu-archive-keyring.gpg')


def ubuntu_source_configuration(apt_root, os_release):
    """Scope CI APT to the runner's existing signed Ubuntu24.04 sources.

    Accept only the standard deb822 layout. Unknown source options must fail
    before excluding other feeds; APT still verifies the original Signed-By
    keyring, release metadata and package signatures normally.
    """
    def unsupported(reason):raise RuntimeError('Unsupported GitHub Actions Ubuntu APT sources: '+reason)
    release=dict(line.split('=',1) for line in os_release.read_text().splitlines() if '=' in line and not line.startswith('#'))
    if release.get('VERSION_ID','').strip('"')!='24.04' or release.get('VERSION_CODENAME','').strip('"')!='noble':
        unsupported('expected Ubuntu24.04/noble.')
    source=apt_root/'sources.list.d'/'ubuntu.sources'
    if source.parent.is_symlink() or source.is_symlink() or not source.is_file():unsupported('regular ubuntu.sources required.')
    disabled_parts=apt_root/'-'
    if disabled_parts.exists() or disabled_parts.is_symlink():unsupported('disabled sourceparts path must be absent.')
    if UBUNTU_KEYRING.parent.is_symlink() or UBUNTU_KEYRING.is_symlink() or not UBUNTU_KEYRING.is_file():unsupported('regular Ubuntu archive keyring required.')
    if source.stat().st_mode&0o022 or UBUNTU_KEYRING.stat().st_mode&0o022:unsupported('source/keyring must not be group/world writable.')
    stanzas=[];fields={}
    for line in source.read_text().splitlines()+['']:
        if not line.strip():
            if fields:stanzas.append(fields);fields={}
            continue
        if line.lstrip().startswith('#'):continue
        match=re.fullmatch(r'([A-Za-z][A-Za-z-]*):[ \t]*(\S.*)',line)
        if not match or match[1].lower() in fields:unsupported('malformed, continued or duplicate deb822 field.')
        fields[match[1].lower()]=match[2].strip()
    required={'types','uris','suites','components','signed-by'}
    suites=set();official={'https://archive.ubuntu.com/ubuntu','https://archive.ubuntu.com/ubuntu/','https://security.ubuntu.com/ubuntu','https://security.ubuntu.com/ubuntu/'}
    mirror=apt_root/'apt-mirrors.txt';mirror_uri='mirror+file:'+str(mirror)
    if not stanzas:unsupported('empty ubuntu.sources.')
    for fields in stanzas:
        if not required<=fields.keys() or fields.keys()-required-{'architectures','enabled'}:unsupported('unexpected or missing deb822 fields.')
        if fields['types']!='deb' or fields.get('enabled','yes')!='yes':unsupported('active binary package sources required.')
        if 'architectures' in fields and (not fields['architectures'].split() or set(fields['architectures'].split())-{'amd64','arm64'}):unsupported('unsupported source architecture.')
        if fields['signed-by']!=str(UBUNTU_KEYRING):unsupported('Ubuntu archive Signed-By keyring required.')
        selected=set(fields['suites'].split())
        if not selected or selected-{'noble','noble-updates','noble-backports','noble-security'}:unsupported('suite does not match noble.')
        suites.update(selected)
        if set(fields['components'].split())!={'main','restricted','universe','multiverse'}:unsupported('standard Ubuntu components required.')
        for uri in fields['uris'].split():
            if uri==mirror_uri:
                if mirror.is_symlink() or not mirror.is_file():unsupported('regular Ubuntu mirrorlist required.')
            elif uri not in official:unsupported('official Ubuntu HTTPS URI or standard mirrorlist required.')
    if not {'noble','noble-updates','noble-security'}<=suites:unsupported('base, updates and security suites required.')
    # The source path is installed into APT syntax, so reject quoting/control
    # characters even in a nonstandard test/workspace apt_root.
    if any(character in str(source) for character in '"\\\r\n'):unsupported('unsupported source path.')
    return f'Dir::Etc::sourcelist "{source}";\nDir::Etc::sourceparts "{disabled_parts}";\n'


def privileged(command):
    prefix=[] if os.geteuid()==0 else ['sudo','-n','--']
    subprocess.run(prefix+command,check=True,timeout=30)


def dependency_failure(text, status=None):
    if re.search(r'Installation process exited with code:\s*100|Failed to install (?:browser )?dependencies|^E: (?:Failed to fetch|Unable to fetch)|Temporary failure resolving[^\n]*ubuntu\.com',text,re.I|re.M):
        return True
    # A stopped APT transfer may never print its normal E: diagnostic. Retry
    # only when our own deadline fired and the last actual subprocess output
    # still identifies an Ubuntu APT download. Earlier successful APT output
    # must not turn a later browser-CDN or unrelated timeout into a mirror retry.
    if status!=124:return False
    lines=[line.strip() for line in text.splitlines() if line.strip()]
    if not lines or not re.fullmatch(r'CI dependency attempt exceeded [0-9.]+s; no success was inferred\.',lines[-1]):return False
    lines.pop()
    return bool(lines and re.match(r'^(?:Get|Ign):\d+ https?://(?:[a-z0-9-]+\.)*ubuntu\.com/ubuntu(?:/| )',lines[-1],re.I))


def execute(commands, timeout, root_command=privileged):
    """One deadline for the entire attempt; terminate only our process group."""
    output=[];deadline=time.monotonic()+timeout
    for command in commands:
        process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,start_new_session=True)
        try:
            text,_=process.communicate(timeout=max(.01,deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            # A Playwright wrapper may have root-owned sudo/apt children. Signal
            # only the new process group we created, with the same authorized
            # privilege boundary used for dependency installation.
            root_command(['kill','-TERM','--','-'+str(process.pid)])
            try:text,_=process.communicate(timeout=10)
            except subprocess.TimeoutExpired:
                root_command(['kill','-KILL','--','-'+str(process.pid)])
                try:text,_=process.communicate(timeout=10)
                except subprocess.TimeoutExpired:
                    if process.stdout is not None:process.stdout.close()
                    process.wait(timeout=5)
                    raise RuntimeError('Dependency process kept output open after group termination; refusing an unbounded wait.')
            output.append(text or '')
            output.append(f'CI dependency attempt exceeded {timeout:g}s; no success was inferred.\n')
            return 124,''.join(output)
        output.append(text or '')
        if process.returncode:return process.returncode,''.join(output)
    return 0,''.join(output)


def install(mode, arguments, log_path, *, timeout=300, apt_root=Path('/etc/apt'), os_release=Path('/etc/os-release'), root_command=privileged):
    log_path=Path(log_path);log_path.parent.mkdir(parents=True,exist_ok=True)
    # Workflows tee npm bootstrap output into this file before invoking us.
    with log_path.open('a') as log:
        def emit(text):
            print(text,end='' if text.endswith('\n') else '\n',flush=True)
            log.write(text+('' if text.endswith('\n') else '\n'));log.flush()
        emit('CI dependency setup: at most two system attempts; official Ubuntu HTTPS first on supported GitHub Actions runners.')
        if mode=='playwright':
            if len(arguments)<2 or not Path(arguments[0]).is_file() or any(browser not in ('chromium','webkit','firefox') for browser in arguments[1:]):
                emit('Invalid Playwright binary or browser selection.');return 2
            commands=[[arguments[0],'install-deps',*arguments[1:]]]
            browser_commands=[[arguments[0],'install',*arguments[1:]]]
        elif mode=='apt':
            if not arguments or any(not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*',package) for package in arguments):
                emit('Invalid APT package selection.');return 2
            prefix=[] if os.geteuid()==0 else ['sudo','-n','--']
            commands=[prefix+['apt-get','update'],prefix+['apt-get','install','-y',*arguments]]
        else:emit('Unknown installer mode.');return 2
        if not 0<timeout<=600:emit('Attempt timeout must be positive and no more than600seconds.');return 2
        ubuntu=os_release.is_file() and any(line.strip() in ('ID=ubuntu','ID="ubuntu"') for line in os_release.read_text().splitlines())
        github_actions=os.environ.get('GITHUB_ACTIONS')=='true'
        mirror=apt_root/'apt-mirrors.txt'
        configuration=apt_root/'apt.conf.d'/f'99-orafold-playwright-{os.getpid()}.conf'
        def system_dependencies():
            with tempfile.TemporaryDirectory(prefix='orafold-ci-deps-') as folder:
                temporary=Path(folder);owned_configuration=False;changed_mirror=False
                try:
                    source_configuration=ubuntu_source_configuration(apt_root,os_release) if github_actions and ubuntu else ''
                    if source_configuration and not configuration.parent.is_dir():raise RuntimeError('APT configuration directory required for Ubuntu source isolation.')
                    if ubuntu and configuration.parent.is_dir():
                        if configuration.exists() or configuration.is_symlink():raise RuntimeError('Refusing to overwrite an existing installer configuration.')
                        source=temporary/'limits.conf';source.write_text(APT_LIMITS+source_configuration)
                        owned_configuration=True
                        root_command(['install','-m','0644',str(source),str(configuration)])
                        if source_configuration:emit('System APT sources: validated signed Ubuntu24.04 ubuntu.sources only; unrelated runner feeds temporarily excluded without editing their files. TLS, signatures and update errors remain enforced.')
                    supported_mirror=ubuntu and mirror.is_file() and not mirror.is_symlink()
                    official_first=github_actions and supported_mirror
                    def select_official_mirrors():
                        nonlocal changed_mirror
                        backup=temporary/'original-mirrors.txt'
                        root_command(['cp','-p',str(mirror),str(backup)])
                        official=temporary/'official-mirrors.txt';official.write_text(OFFICIAL_MIRRORS)
                        changed_mirror=True
                        root_command(['cp',str(official),str(mirror)])
                    if official_first:
                        select_official_mirrors()
                        emit('Attempt1: official Ubuntu archive/security HTTPS mirrors; GitHub Actions Ubuntu regular mirrorlist avoids slow runner HTTP mirrors. Signatures, TLS and dependency validation unchanged.')
                    else:
                        reason='GITHUB_ACTIONS is not true; normal-first behavior' if not github_actions else 'supported regular Ubuntu mirrorlist unavailable'
                        emit(f'Attempt1: original mirror configuration ({reason}); required dependencies remain enabled.')
                    status,text=execute(commands,timeout,root_command);emit(text)
                    if status==0:emit('Dependency installation succeeded.');return 0
                    emit(f'Attempt1 failed with exit{status}.')
                    if not dependency_failure(text,status):emit('Not an Ubuntu dependency-download failure; no further mirror changes or retry.');return status
                    if not ubuntu or not mirror.is_file() or mirror.is_symlink():
                        emit('Supported regular Ubuntu mirrorlist unavailable; original failure remains.');return status
                    if not official_first:select_official_mirrors()
                    reason='one bounded retry after an Ubuntu dependency-download failure' if official_first else 'fallback after an Ubuntu dependency-download failure'
                    emit(f'Attempt2: official Ubuntu archive/security HTTPS mirrors; {reason}. Signatures, TLS and dependency validation unchanged.')
                    status,text=execute(commands,timeout,root_command);emit(text)
                    emit('Dependency installation succeeded after the official retry.' if status==0 else f'Official retry failed with exit{status}; CI remains failed.')
                    return status
                finally:
                    cleanup_errors=[]
                    if changed_mirror:
                        try:root_command(['cp','-p',str(temporary/'original-mirrors.txt'),str(mirror)])
                        except Exception as error:cleanup_errors.append('mirror restoration: '+type(error).__name__)
                    if owned_configuration:
                        try:root_command(['rm','-f','--',str(configuration)])
                        except Exception as error:cleanup_errors.append('temporary configuration removal: '+type(error).__name__)
                    if cleanup_errors:
                        emit('Installer cleanup failed: '+', '.join(cleanup_errors))
                        raise RuntimeError('Dependency setup configuration could not be restored.')
        emit(f'System dependency phase: at most two attempts, each bounded to {timeout:g}s.')
        status=system_dependencies()
        if status or mode=='apt':return status
        # Pinned Playwright1.65 uses the same installDeps/registry.install/host
        # validation path for --with-deps. Split its public commands so a slow
        # successful APT phase cannot consume the browser download/unpack time.
        # Do not put this phase in the APT retry scope: CDN/validation errors
        # must fail once, with no mirror changes or success inferred at100%.
        emit(f'Browser download and host validation phase: one attempt bounded to {timeout:g}s; APT configuration already restored.')
        status,text=execute(browser_commands,timeout,root_command);emit(text)
        emit('Browser installation completed; normal Playwright host validation remains enabled.' if status==0 else f'Browser installation failed with exit{status}; CI remains failed.')
        return status


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log',type=Path,required=True)
    parser.add_argument('--attempt-timeout',type=int,default=300)
    parser.add_argument('mode',choices=('playwright','apt'))
    parser.add_argument('arguments',nargs='+')
    args=parser.parse_args()
    try:return install(args.mode,args.arguments,args.log,timeout=args.attempt_timeout)
    except Exception as error:
        # No environment/credential dump. The failure remains visible even
        # before any application test has produced its own evidence files.
        message='CI dependency setup failed: '+type(error).__name__+': '+str(error)
        print(message,file=sys.stderr)
        with args.log.open('a') as log:log.write(message+'\n')
        return 1


if __name__=='__main__':sys.exit(main())
