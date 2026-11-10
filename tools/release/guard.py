"""Fail-closed Pages preflight; read-only API calls, no deployment side effects."""
import json
import os
import re
import urllib.request


class Denied(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise Denied(message)


def validate(context, evidence):
    repo = context['repository']
    sha = context['sha']
    require(repo == 'Jagarex-lab/nachtsiegel-app', 'wrong repository')
    require(context['event'] == 'workflow_dispatch', 'manual dispatch only')
    require(context['ref'] == 'refs/heads/develop', 'develop branch only, no tags')
    require(re.fullmatch(r'[0-9a-f]{40}', sha) is not None, 'full lowercase commit SHA required')
    require(context['confirmation'] == 'PUBLISH ' + sha, 'explicit SHA confirmation required')
    require(context['run_id'].isdigit(), 'numeric QA run required')
    require(evidence['develop_sha'] == sha == context['dispatch_sha'], 'stale or mismatched commit')
    require(evidence['pages']['build_type'] == 'workflow', 'branch-based Pages forbidden')
    env = evidence['environment']
    # Solo-alpha policy: GitHub itself enforces any active environment reviewers,
    # timers and branch restrictions. Do not require or remove a second identity.
    policy = env.get('deployment_branch_policy', {}) or {}
    if policy.get('custom_branch_policies'):
        require({'name': 'develop', 'type': 'branch'} in evidence['policies'], 'environment must allow develop explicitly')
    run = evidence['run']
    require(str(run['id']) == context['run_id'], 'wrong QA run')
    require(run['repository']['full_name'] == repo, 'foreign QA run')
    require(run['head_sha'] == sha and run['head_branch'] == 'develop', 'QA commit/branch mismatch')
    require(run['event'] in ('push', 'workflow_dispatch') and run['status'] == 'completed' and run['conclusion'] == 'success', 'successful exact-develop push or manual QA required')
    require(run['path'] == '.github/workflows/web-preview.yml', 'wrong QA workflow')
    artifacts = evidence['artifacts']
    require(len(artifacts) == 1 and not artifacts[0]['expired'], 'one unexpired QA artifact required')
    return sha


def get(path):
    req = urllib.request.Request('https://api.github.com/repos/Jagarex-lab/nachtsiegel-app/' + path,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'], 'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def main():
    c = {key: os.environ[name] for key, name in {
        'repository':'GITHUB_REPOSITORY', 'event':'GITHUB_EVENT_NAME', 'ref':'GITHUB_REF',
        'dispatch_sha':'GITHUB_SHA', 'sha':'RELEASE_SHA', 'confirmation':'RELEASE_CONFIRMATION',
        'run_id':'QA_RUN_ID'}.items()}
    # Validate input before putting run ID into a URL. All failure/403 paths abort.
    require(c['run_id'].isdigit(), 'numeric QA run required')
    e = {'develop_sha':get('git/ref/heads/develop')['object']['sha'], 'pages':get('pages'),
         'environment':get('environments/github-pages'),
         'policies':[{k:p[k] for k in ('name','type')} for p in get('environments/github-pages/deployment-branch-policies')['branch_policies']],
         'run':get('actions/runs/' + c['run_id']),
         'artifacts':[a for a in get('actions/runs/' + c['run_id'] + '/artifacts')['artifacts'] if a['name']=='nachtsiegel-arena-qa']}
    print('Approved tested candidate (active GitHub environment rules still apply):', validate(c,e))


if __name__ == '__main__':
    main()
