import copy
import importlib.util
import itertools
import unittest
from pathlib import Path
from types import SimpleNamespace
import yaml

spec=importlib.util.spec_from_file_location('guard',Path('tools/release/guard.py'))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
SHA='a'*40
WORKFLOW_ROOT = Path('.github/workflows')
RELEASE_SUITES = {
    'web-preview.yml': ('NACHTSIEGEL CI (no deployment)', 20),
    'alpha-qa.yml': ('ORAFOLD isolated Alpha QA (no deployment)', 4),
    'release-safety.yml': ('Release safety (no deployment)', 1),
    'legacy-foundations.yml': ('Legacy P01-P07 (no deployment)', 1),
    'economy-qa.yml': ('ORAFOLD isolated economy QA (no deployment)', 1),
    'campaign-orafold-qa.yml': ('ORAFOLD campaign QA (no deployment)', 1),
    'online-qa.yml': ('ORAFOLD online authority integration QA (no deployment)', 1),
}


def workflows():
    return {p.name: yaml.load(p.read_text(), Loader=yaml.BaseLoader)
            for p in WORKFLOW_ROOT.iterdir() if p.suffix in ('.yml', '.yaml')}


def expanded_jobs(name, all_workflows):
    """Count the actual reusable and matrix jobs, not just top-level job keys."""
    total = 0
    for job in all_workflows[name]['jobs'].values():
        if 'uses' in job:
            assert job['uses'].startswith('./.github/workflows/'), 'trusted local reusable workflow required'
            total += expanded_jobs(Path(job['uses']).name, all_workflows)
        else:
            matrix = job.get('strategy', {}).get('matrix', {})
            assert not set(matrix).intersection({'include', 'exclude'}), 'review changed release matrix'
            total += len(list(itertools.product(*matrix.values())))
    return total


def allowed(expression, context):
    """Evaluate checked-in guards/queue expressions over fake GitHub data."""
    def namespace(value):
        return SimpleNamespace(**{key: namespace(item) for key, item in value.items()}) if isinstance(value, dict) else value
    expression=expression.strip()
    if expression.startswith('${{') and expression.endswith('}}'):
        expression=expression[3:-2].strip()
    values={key: namespace(value) for key, value in context.items()}
    values['format']=lambda template,*arguments: template.format(*arguments)
    return eval('(' + expression.replace('&&', ' and ').replace('||', ' or ') + ')',
                {'__builtins__': {}}, values)


def trusted_trigger():
    return {
        'github': {
            'repository': 'Jagarex-lab/nachtsiegel-app', 'ref': 'refs/heads/develop',
            'sha': SHA, 'run_id': '100',
            'event_name': 'workflow_run', 'event': {
                'action': 'completed', 'repository': {'default_branch': 'develop'},
                'workflow_run': {
                    'repository': {'full_name': 'Jagarex-lab/nachtsiegel-app'},
                    'head_repository': {'full_name': 'Jagarex-lab/nachtsiegel-app'},
                    'head_branch': 'develop', 'head_sha': SHA, 'event': 'push',
                    'status': 'completed', 'conclusion': 'success',
                },
            },
        },
        'needs': {'preflight': {'result': 'success', 'outputs': {'ready': 'true'}},
                  'publish': {'result': 'success'}},
    }


def valid():
    return ({'repository':'Jagarex-lab/nachtsiegel-app','event':'workflow_dispatch','ref':'refs/heads/develop','enabled':'true','sha':SHA,'dispatch_sha':SHA,'confirmation':'PUBLISH '+SHA,'run_id':'42'},
        {'develop_sha':SHA,'pages':{'build_type':'workflow'},'environment':{'can_admins_bypass':False,'protection_rules':[{'type':'required_reviewers','prevent_self_review':True,'reviewers':[{'id':1}]}],'deployment_branch_policy':{'custom_branch_policies':True,'protected_branches':False}},'policies':[{'name':'develop','type':'branch'}],'run':{'id':42,'repository':{'full_name':'Jagarex-lab/nachtsiegel-app'},'head_sha':SHA,'head_branch':'develop','event':'push','status':'completed','conclusion':'success','path':'.github/workflows/web-preview.yml'},'artifacts':[{'expired':False}]})


class Safety(unittest.TestCase):
    def test_approved_candidate_only(self):
        c,e=valid();self.assertEqual(g.validate(c,e),SHA)

    def test_manual_qa_still_requires_exact_trusted_develop(self):
        c,e=valid();e['run']['event']='workflow_dispatch'
        self.assertEqual(g.validate(c,e),SHA)
        for key,value in [('head_sha','b'*40),('head_branch','feature/test'),('path','.github/workflows/other.yml'),('conclusion','failure')]:
            bad=copy.deepcopy(e);bad['run'][key]=value
            with self.subTest(key=key),self.assertRaises(g.Denied):g.validate(c,bad)

    def test_event_ref_switch_matrix(self):
        # 6 events x 5 refs x 3 switch values; no API/deployment side effects.
        for event in ['push','pull_request','workflow_dispatch','workflow_run','repository_dispatch','release']:
            for ref in ['refs/heads/develop','refs/heads/main','refs/heads/feature/test','refs/tags/v1','refs/pull/6/merge']:
                for enabled in ['', 'false','true']:
                    c,e=valid();c.update(event=event,ref=ref,enabled=enabled)
                    with self.subTest(event=event,ref=ref,enabled=enabled):
                        if (event,ref)==('workflow_dispatch','refs/heads/develop'):self.assertEqual(g.validate(c,e),SHA)
                        else:
                            with self.assertRaises(g.Denied):g.validate(c,e)

    def test_solo_alpha_and_existing_environment_rules(self):
        c,e=valid()
        e['environment']['protection_rules']=[]
        e['environment']['can_admins_bypass']=True
        e['policies'].append({'name':'main','type':'branch'})
        before=copy.deepcopy(e)
        self.assertEqual(g.validate(c,e),SHA)
        self.assertEqual(e,before)  # Never modify GitHub protections.
        e['environment']['protection_rules']=[{'type':'required_reviewers','reviewers':[{'id':1}]}]
        self.assertEqual(g.validate(c,e),SHA)  # GitHub enforces these natively.
        for event in ['push','pull_request','release','workflow_run']:
            c['event']=event
            with self.assertRaises(g.Denied):g.validate(c,e)

    def test_context_rejections(self):
        for key,value in [('repository','fork/game'),('sha','main'),('sha','A'*40),('confirmation','yes'),('run_id','../42'),('dispatch_sha','b'*40)]:
            c,e=valid();c[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(g.Denied):g.validate(c,e)

    def test_missing_or_weakened_settings_and_qa(self):
        mutations=[lambda e:e.update(develop_sha='b'*40),lambda e:e['pages'].update(build_type='legacy'),lambda e:e.update(policies=[{'name':'*','type':'tag'}]),lambda e:e['run'].update(id=43),lambda e:e['run']['repository'].update(full_name='fork/game'),lambda e:e['run'].update(head_sha='b'*40),lambda e:e['run'].update(head_branch='feature/test'),lambda e:e['run'].update(event='pull_request'),lambda e:e['run'].update(status='in_progress'),lambda e:e['run'].update(conclusion='failure'),lambda e:e['run'].update(path='.github/workflows/other.yml'),lambda e:e.update(artifacts=[]),lambda e:e['artifacts'][0].update(expired=True),lambda e:e['artifacts'].append({'expired':False})]
        for i,mutate in enumerate(mutations):
            c,e=valid();mutate(e)
            with self.subTest(case=i),self.assertRaises(g.Denied):g.validate(c,e)

    def test_api_errors_are_not_swallowed(self):
        source=Path('tools/release/guard.py').read_text()
        self.assertNotIn('except',source)
        self.assertNotIn('deploy-pages',source)

    def test_workflow_privilege_boundaries(self):
        all_workflows=workflows()
        publishers=[]
        for name,w in all_workflows.items():
            self.assertEqual(w['permissions'],{'contents':'read'})
            for job_name,job in w['jobs'].items():
                privileged=any(value=='write' for value in job.get('permissions',{}).values())
                deploy_steps=[s for s in job.get('steps',[]) if 'deploy-pages@' in s.get('uses','') or 'upload-pages-artifact@' in s.get('uses','')]
                if privileged or deploy_steps:
                    self.assertEqual((name,job_name),('pages-release.yml','publish'))
                    self.assertEqual(job['environment']['name'],'github-pages')
                    self.assertEqual(job['needs'],'preflight')
                publishers.extend((name,job_name) for s in deploy_steps if 'deploy-pages@' in s['uses'])
        self.assertEqual(publishers,[('pages-release.yml','publish')])
        release=all_workflows['pages-release.yml']
        self.assertEqual(release['concurrency']['cancel-in-progress'],'false')
        self.assertEqual(allowed(release['concurrency']['group'],trusted_trigger()),'nachtsiegel-pages-release')
        self.assertEqual(release['jobs']['preflight']['permissions'],{'contents':'read','actions':'read','pages':'read'})
        self.assertEqual(release['jobs']['publish']['permissions'],{'contents':'read','actions':'read','pages':'write','id-token':'write'})
        self.assertEqual(release['jobs']['verify-public']['permissions'],{'contents':'read'})
        for job in release['jobs'].values():
            for step in job['steps']:
                if 'uses' in step:self.assertRegex(step['uses'],r'@[0-9a-f]{40}$')
        ci=Path('.github/workflows/web-preview.yml').read_text()
        self.assertNotIn('deploy-pages',ci);self.assertNotIn('upload-pages-artifact',ci);self.assertNotIn('id-token:',ci)

    def test_ineligible_completions_cannot_replace_valid_pending_release(self):
        concurrency=workflows()['pages-release.yml']['concurrency']
        expression=concurrency['group']
        running=trusted_trigger()
        pending=trusted_trigger();pending['github']['run_id']='101'
        shared=allowed(expression,running)
        self.assertEqual(allowed(expression,pending),shared)
        # GitHub allows one running and one pending run per concurrency group;
        # enqueueing another run replaces that group's existing pending run.
        for scenario in ['failed','stale','foreign']:
            incoming=trusted_trigger();incoming['github']['run_id']='102'
            source=incoming['github']['event']['workflow_run']
            if scenario=='failed':source['conclusion']='failure'
            elif scenario=='stale':source['head_sha']='b'*40
            else:source['head_repository']['full_name']='fork/game'
            queue={shared:pending}
            incoming_group=allowed(expression,incoming)
            queue[incoming_group]=incoming
            with self.subTest(scenario=scenario):
                self.assertEqual(incoming_group,'nachtsiegel-pages-release-ignored-102')
                self.assertIs(queue[shared],pending)
                self.assertEqual(len(queue),2)
        dispatch=trusted_trigger();dispatch['github']['event_name']='workflow_dispatch'
        del dispatch['github']['event']['workflow_run']
        self.assertEqual(allowed(expression,dispatch),shared)
        for key,value in [('repository','fork/game'),('ref','refs/heads/main')]:
            invalid=copy.deepcopy(dispatch);invalid['github'][key]=value
            self.assertNotEqual(allowed(expression,invalid),shared)
        invalid=copy.deepcopy(dispatch);invalid['github']['event']['repository']['default_branch']='main'
        self.assertNotEqual(allowed(expression,invalid),shared)
        other=trusted_trigger();other['github']['run_id']='103'
        other['github']['event']['workflow_run']['conclusion']='failure'
        self.assertEqual(allowed(expression,other),'nachtsiegel-pages-release-ignored-103')
        self.assertEqual(concurrency['cancel-in-progress'],'false')

    def test_all_seven_postmerge_workflows_and_29_jobs_are_required(self):
        all_workflows=workflows()
        release=all_workflows['pages-release.yml']
        self.assertEqual(set(release['on']),{'workflow_run','workflow_dispatch'})
        self.assertFalse(release['on']['workflow_dispatch'])  # No arbitrary source or confirmation inputs.
        trigger=release['on']['workflow_run']
        self.assertEqual(trigger['branches'],['develop'])
        self.assertEqual(trigger['types'],['completed'])
        self.assertEqual(set(trigger['workflows']),{name for name,count in RELEASE_SUITES.values()})
        self.assertEqual(len(trigger['workflows']),7)
        for path,(name,count) in RELEASE_SUITES.items():
            with self.subTest(path=path):
                workflow=all_workflows[path]
                self.assertEqual(workflow['name'],name)
                self.assertIn('develop',workflow['on']['push']['branches'])
                self.assertEqual(set(workflow['on']['push']),{'branches'})  # Postmerge QA cannot be path-filtered.
                self.assertEqual(expanded_jobs(path,all_workflows),count)
        self.assertEqual(sum(expanded_jobs(path,all_workflows) for path in RELEASE_SUITES),29)

    def test_original_pr_filters_and_feature_pushes_are_preserved(self):
        all_workflows=workflows()
        self.assertEqual(all_workflows['alpha-qa.yml']['on']['pull_request'],{'branches':['develop']})
        self.assertIn('alpha/**',all_workflows['alpha-qa.yml']['on']['push']['branches'])
        self.assertEqual(all_workflows['legacy-foundations.yml']['on']['pull_request']['branches'],
                         ['develop','feature/legacy-foundations','feature/legacy-engine-p01-p04','feature/legacy-engine-p05-p06'])
        expected_paths={
            'economy-qa.yml':['data/economy/**','scripts/economy/**','scenes/economy/**','tools/economy/**','tests/economy*','docs/economy/**','.github/workflows/economy-qa.yml'],
            'campaign-orafold-qa.yml':['data/campaign_orafold/**','scripts/campaign_orafold/**','scenes/campaign_orafold/**','assets/campaign_orafold/**','tests/campaign_orafold/**','tools/*campaign_orafold*','.github/workflows/campaign-orafold-qa.yml'],
            'online-qa.yml':['server/**','scripts/online/**','shared/**','tests/online*','data/online/**','docs/online/**','.github/workflows/online-qa.yml'],
        }
        for path,paths in expected_paths.items():
            self.assertEqual(all_workflows[path]['on']['pull_request'],{'branches':['develop'],'paths':paths})
        self.assertIn('feature/orafold-campaign',all_workflows['campaign-orafold-qa.yml']['on']['push']['branches'])
        self.assertIn('feature/orafold-online',all_workflows['online-qa.yml']['on']['push']['branches'])

    def test_public_integrity_regressions_are_mandatory_release_qa(self):
        steps=workflows()['release-safety.yml']['jobs']['release-safety']['steps']
        setup=next(step for step in steps if step.get('uses','').startswith('actions/setup-node@'))
        self.assertEqual(setup['uses'],'actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020')
        self.assertEqual(setup['with']['node-version'],'24')
        commands=[step.get('run') for step in steps]
        for command in ['python3 -m unittest discover -s tests/release -v',
                        'python3 -m unittest discover -s tests/ci -v',
                        'node --test tests/release/public_integrity.test.cjs']:
            step=next(step for step in steps if step.get('run')==command)
            self.assertNotIn('continue-on-error',step)
            self.assertNotIn('if',step)
        self.assertLess(steps.index(setup),commands.index('node --test tests/release/public_integrity.test.cjs'))

    def test_untrusted_events_are_rejected_before_any_checkout(self):
        jobs=workflows()['pages-release.yml']['jobs']
        for name,job in jobs.items():
            self.assertTrue(allowed(job['if'],trusted_trigger()),name)
            mutations=[
                ('repository','fork/game'),('ref','refs/heads/main'),('ref','refs/heads/feature/test'),
                ('ref','refs/tags/v1'),('ref','refs/pull/6/merge'),('event_name','pull_request'),
                ('event_name','push'),('event_name','repository_dispatch'),('event_name','release'),
            ]
            for key,value in mutations:
                context=trusted_trigger();context['github'][key]=value
                with self.subTest(job=name,key=key,value=value):self.assertFalse(allowed(job['if'],context))
            for path,value in [
                (['repository','default_branch'],'main'),(['action'],'requested'),
                (['workflow_run','repository','full_name'],'fork/game'),
                (['workflow_run','head_repository','full_name'],'fork/game'),
                (['workflow_run','head_branch'],'feature/test'),(['workflow_run','event'],'pull_request'),
                (['workflow_run','event'],'workflow_dispatch'),(['workflow_run','status'],'in_progress'),
                (['workflow_run','conclusion'],'failure'),(['workflow_run','conclusion'],'cancelled'),
                (['workflow_run','conclusion'],'skipped'),
            ]:
                context=trusted_trigger();target=context['github']['event']
                for key in path[:-1]:target=target[key]
                target[path[-1]]=value
                with self.subTest(job=name,path=path,value=value):self.assertFalse(allowed(job['if'],context))
            context=trusted_trigger();context['github']['event_name']='workflow_dispatch'
            del context['github']['event']['workflow_run']
            self.assertTrue(allowed(job['if'],context),name)
        publish=jobs['publish']
        for ready in ['false','']:
            context=trusted_trigger();context['needs']['preflight']['outputs']['ready']=ready
            self.assertFalse(allowed(publish['if'],context))
        context=trusted_trigger();context['needs']['preflight']['result']='failure'
        self.assertFalse(allowed(publish['if'],context))
        self.assertEqual(jobs['preflight']['steps'][0]['with']['ref'],'${{ github.sha }}')
        self.assertEqual(publish['steps'][0]['with']['ref'],'${{ needs.preflight.outputs.commit }}')

    def test_actual_playwright_polling_is_mandatory_before_both_browser_journeys(self):
        job=workflows()['web-preview.yml']['jobs']['browser']
        self.assertEqual(job['strategy']['matrix']['engine'],['chromium','webkit'])
        self.assertEqual(job['strategy']['fail-fast'],'false')
        self.assertEqual(job['timeout-minutes'],'75','the original complete-browser budget is retained')
        self.assertEqual(job['env']['QA_ENGINES'],'${{ matrix.engine }}')
        steps=job['steps']
        index=next(i for i,step in enumerate(steps) if step.get('run')=='node --test tests/production/playwright_polling.test.cjs')
        self.assertNotIn('if',steps[index])
        self.assertNotIn('continue-on-error',steps[index])
        install=next(i for i,step in enumerate(steps) if 'playwright@1.65.0' in step.get('run',''))
        serve=next(i for i,step in enumerate(steps) if step.get('name')=='Serve the three tested builds')
        self.assertLess(install,index)
        self.assertLess(index,serve)
        for name in ['Archive tutorial, saved reload and collection browser regression',
                     'Complete Alpha browser duels and replay',
                     'Mobile orientation, Retina and deckbuilder browser regression',
                     'Actual previous-version upgrade, stale-tab write and storage quota regression',
                     'Master card system and battlefield opening browser regression']:
            self.assertTrue(any(step.get('name')==name for step in steps),name)

    def test_tested_artifact_rechecks_and_public_evidence_hash_are_wired(self):
        release=workflows()['pages-release.yml'];jobs=release['jobs']
        self.assertEqual(jobs['preflight']['outputs'],{
            'ready':'${{ steps.candidate.outputs.ready }}','commit':'${{ steps.candidate.outputs.commit }}',
            'candidate':'${{ steps.candidate.outputs.candidate }}'})
        publish=jobs['publish'];steps=publish['steps']
        commands=[step.get('run') for step in steps]
        self.assertEqual(commands.count('python3 tools/release/candidate.py recheck'),2)
        download=next(step for step in steps if step.get('run')=='python3 tools/release/candidate.py download')
        self.assertEqual(download['id'],'download')
        deploy=next(i for i,step in enumerate(steps) if 'deploy-pages@' in step.get('uses',''))
        self.assertEqual(steps[deploy-1]['run'],'python3 tools/release/candidate.py recheck')
        self.assertEqual(steps[1]['run'],'python3 tools/release/candidate.py recheck')
        upload=next(step for step in steps if 'upload-pages-artifact@' in step.get('uses',''))
        self.assertEqual(upload['with']['path'],'work/release-web')
        self.assertEqual(publish['outputs']['evidence_sha256'],'${{ steps.download.outputs.evidence_sha256 }}')
        self.assertEqual(publish['outputs']['page_url'],'${{ steps.deployment.outputs.page_url }}')
        public=jobs['verify-public']
        self.assertEqual(public['needs'],['preflight','publish'])
        self.assertEqual(public['env']['EXPECTED_RELEASE_EVIDENCE_SHA256'],'${{ needs.publish.outputs.evidence_sha256 }}')
        install=next(step['run'] for step in public['steps'] if 'playwright@' in step.get('run',''))
        self.assertIn('playwright@1.65.0',install)
        self.assertIn('python3 tools/ci/install_dependencies.py',install)
        self.assertIn('chromium webkit',install)
        receipt=public['steps'][-1]
        self.assertEqual(receipt['if'],'always()')
        self.assertEqual(receipt['with']['path'],'work/release-public/')
        self.assertEqual(receipt['with']['if-no-files-found'],'error')
        source=Path('.github/workflows/pages-release.yml').read_text()
        for forbidden in ['export-debug','export-release','setup-godot','tools/build_','guard.py','RELEASE_CONFIRMATION','inputs.']:
            self.assertNotIn(forbidden,source)
        pins={step['uses'].split('@')[0]:step['uses'].split('@')[1]
              for job in jobs.values() for step in job['steps'] if 'uses' in step}
        self.assertEqual(pins,{
            'actions/checkout':'11d5960a326750d5838078e36cf38b85af677262',
            'actions/upload-pages-artifact':'56afc609e74202658d3ffba0e8f6dda462b719fa',
            'actions/deploy-pages':'d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e',
            'actions/setup-node':'49933ea5288caeca8642d1e84afbd3f7d6820020',
            'actions/upload-artifact':'ea165f8d65b6e75b540449e92b4886f43607fa02'})


if __name__=='__main__':unittest.main()
