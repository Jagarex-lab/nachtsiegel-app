#!/usr/bin/env python3
"""Bounded CI dependency setup with one official Ubuntu mirror fallback.

Normal mirrors are always tried first. Neither GPG/TLS verification nor
Playwright's --with-deps/host validation is disabled. No repository setting,
publisher or credential is changed. All temporary APT configuration is restored.
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

OFFICIAL_MIRRORS="https://archive.ubuntu.com/ubuntu priority:1\nhttps://security.ubuntu.com/ubuntu priority:2\n"
APT_LIMITS='Acquire::Retries "2";\nAcquire::http::Timeout "20";\nAcquire::https::Timeout "20";\nAPT::Update::Error-Mode "any";\n'


def privileged(command):
    prefix=[] if os.geteuid()==0 else ['sudo','-n','--']
    subprocess.run(prefix+command,check=True,timeout=30)


def dependency_failure(text):
    return bool(re.search(r'Installation process exited with code:\s*100|Failed to install (?:browser )?dependencies|^E: (?:Failed to fetch|Unable to fetch)|Temporary failure resolving[^\n]*ubuntu\.com',text,re.I|re.M))


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
        emit('CI dependency setup: normal mirrors first; at most one official fallback.')
        if mode=='playwright':
            if len(arguments)<2 or not Path(arguments[0]).is_file() or any(browser not in ('chromium','webkit','firefox') for browser in arguments[1:]):
                emit('Invalid Playwright binary or browser selection.');return 2
            commands=[[arguments[0],'install','--with-deps',*arguments[1:]]]
        elif mode=='apt':
            if not arguments or any(not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*',package) for package in arguments):
                emit('Invalid APT package selection.');return 2
            prefix=[] if os.geteuid()==0 else ['sudo','-n','--']
            commands=[prefix+['apt-get','update'],prefix+['apt-get','install','-y',*arguments]]
        else:emit('Unknown installer mode.');return 2
        if not 0<timeout<=600:emit('Attempt timeout must be positive and no more than600seconds.');return 2
        ubuntu=os_release.is_file() and any(line.strip() in ('ID=ubuntu','ID="ubuntu"') for line in os_release.read_text().splitlines())
        mirror=apt_root/'apt-mirrors.txt'
        configuration=apt_root/'apt.conf.d'/f'99-orafold-playwright-{os.getpid()}.conf'
        with tempfile.TemporaryDirectory(prefix='orafold-ci-deps-') as folder:
            temporary=Path(folder);owned_configuration=False;changed_mirror=False
            try:
                if ubuntu and configuration.parent.is_dir():
                    if configuration.exists() or configuration.is_symlink():raise RuntimeError('Refusing to overwrite an existing installer configuration.')
                    source=temporary/'limits.conf';source.write_text(APT_LIMITS)
                    owned_configuration=True
                    root_command(['install','-m','0644',str(source),str(configuration)])
                emit('Attempt1: original mirror configuration; required dependencies remain enabled.')
                status,text=execute(commands,timeout,root_command);emit(text)
                if status==0:emit('Dependency installation succeeded.');return 0
                emit(f'Attempt1 failed with exit{status}.')
                if not dependency_failure(text):emit('Not an Ubuntu dependency-download failure; no mirror changes or retry.');return status
                if not ubuntu or not mirror.is_file() or mirror.is_symlink():
                    emit('Supported regular Ubuntu mirrorlist unavailable; original failure remains.');return status
                backup=temporary/'original-mirrors.txt'
                root_command(['cp','-p',str(mirror),str(backup)])
                official=temporary/'official-mirrors.txt';official.write_text(OFFICIAL_MIRRORS)
                changed_mirror=True
                root_command(['cp',str(official),str(mirror)])
                emit('Attempt2: official Ubuntu archive/security HTTPS mirrors; signatures, TLS and dependency validation unchanged.')
                status,text=execute(commands,timeout,root_command);emit(text)
                emit('Dependency installation succeeded after the official fallback.' if status==0 else f'Official fallback failed with exit{status}; CI remains failed.')
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
