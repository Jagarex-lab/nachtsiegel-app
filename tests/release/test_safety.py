import copy
import importlib.util
import unittest
from pathlib import Path
import yaml

spec=importlib.util.spec_from_file_location('guard',Path('tools/release/guard.py'))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
SHA='a'*40


def valid():
    return ({'repository':'Jagarex-lab/nachtsiegel-app','event':'workflow_dispatch','ref':'refs/heads/develop','enabled':'true','sha':SHA,'dispatch_sha':SHA,'confirmation':'PUBLISH '+SHA,'run_id':'42'},
        {'develop_sha':SHA,'pages':{'build_type':'workflow'},'environment':{'can_admins_bypass':False,'protection_rules':[{'type':'required_reviewers','prevent_self_review':True,'reviewers':[{'id':1}]}],'deployment_branch_policy':{'custom_branch_policies':True,'protected_branches':False}},'policies':[{'name':'develop','type':'branch'}],'run':{'id':42,'repository':{'full_name':'Jagarex-lab/nachtsiegel-app'},'head_sha':SHA,'head_branch':'develop','event':'push','status':'completed','conclusion':'success','path':'.github/workflows/web-preview.yml'},'artifacts':[{'expired':False}]})


class Safety(unittest.TestCase):
    def test_approved_candidate_only(self):
        c,e=valid();self.assertEqual(g.validate(c,e),SHA)

    def test_event_ref_switch_matrix(self):
        # 6 events x 5 refs x 3 switch values; no API/deployment side effects.
        for event in ['push','pull_request','workflow_dispatch','workflow_run','repository_dispatch','release']:
            for ref in ['refs/heads/develop','refs/heads/main','refs/heads/feature/test','refs/tags/v1','refs/pull/6/merge']:
                for enabled in ['', 'false','true']:
                    c,e=valid();c.update(event=event,ref=ref,enabled=enabled)
                    with self.subTest(event=event,ref=ref,enabled=enabled):
                        if (event,ref,enabled)==('workflow_dispatch','refs/heads/develop','true'):self.assertEqual(g.validate(c,e),SHA)
                        else:
                            with self.assertRaises(g.Denied):g.validate(c,e)

    def test_context_rejections(self):
        for key,value in [('repository','fork/game'),('sha','main'),('sha','A'*40),('confirmation','yes'),('run_id','../42'),('dispatch_sha','b'*40)]:
            c,e=valid();c[key]=value
            with self.subTest(key=key,value=value),self.assertRaises(g.Denied):g.validate(c,e)

    def test_missing_or_weakened_settings_and_qa(self):
        mutations=[lambda e:e.update(develop_sha='b'*40),lambda e:e['pages'].update(build_type='legacy'),lambda e:e['environment'].update(protection_rules=[]),lambda e:e['environment']['protection_rules'][0].update(prevent_self_review=False),lambda e:e['environment']['protection_rules'][0].update(reviewers=[]),lambda e:e['environment'].update(can_admins_bypass=True),lambda e:e['environment']['deployment_branch_policy'].update(custom_branch_policies=False),lambda e:e.update(policies=[{'name':'*','type':'tag'}]),lambda e:e['policies'].append({'name':'main','type':'branch'}),lambda e:e['run'].update(id=43),lambda e:e['run']['repository'].update(full_name='fork/game'),lambda e:e['run'].update(head_sha='b'*40),lambda e:e['run'].update(head_branch='feature/test'),lambda e:e['run'].update(event='pull_request'),lambda e:e['run'].update(status='in_progress'),lambda e:e['run'].update(conclusion='failure'),lambda e:e['run'].update(path='.github/workflows/other.yml'),lambda e:e.update(artifacts=[]),lambda e:e['artifacts'][0].update(expired=True),lambda e:e['artifacts'].append({'expired':False})]
        for i,mutate in enumerate(mutations):
            c,e=valid();mutate(e)
            with self.subTest(case=i),self.assertRaises(g.Denied):g.validate(c,e)

    def test_api_errors_are_not_swallowed(self):
        source=Path('tools/release/guard.py').read_text()
        self.assertNotIn('except',source)
        self.assertNotIn('deploy-pages',source)

    def test_workflow_privilege_boundaries(self):
        workflows={p.name:yaml.load(p.read_text(),Loader=yaml.BaseLoader) for p in Path('.github/workflows').glob('*.yml')}
        for name,w in workflows.items():
            self.assertEqual(w['permissions'],{'contents':'read'})
            for job in w['jobs'].values():
                privileged=any(job.get('permissions',{}).get(k)=='write' for k in ['pages','id-token','contents'])
                publishers=[s for s in job.get('steps',[]) if 'deploy-pages@' in s.get('uses','') or 'upload-pages-artifact@' in s.get('uses','')]
                if privileged or publishers:
                    self.assertEqual(name,'pages-release.yml');self.assertEqual(job['environment']['name'],'github-pages')
                    self.assertIn("github.event_name == 'workflow_dispatch'",job['if'])
                    self.assertIn("github.ref == 'refs/heads/develop'",job['if'])
                    self.assertIn("vars.PAGES_RELEASE_ENABLED == 'true'",job['if'])
                    self.assertEqual(job['needs'],'preflight')
                    self.assertIn('python3 tools/release/guard.py',[s.get('run') for s in job['steps']])
        release=workflows['pages-release.yml']
        self.assertEqual(set(release['on']),{'workflow_dispatch'})
        self.assertEqual(release['concurrency']['cancel-in-progress'],'false')
        for job in release['jobs'].values():
            for step in job['steps']:
                if 'uses' in step:self.assertRegex(step['uses'],r'@[0-9a-f]{40}$')
        ci=Path('.github/workflows/web-preview.yml').read_text()
        self.assertNotIn('deploy-pages',ci);self.assertNotIn('upload-pages-artifact',ci);self.assertNotIn('id-token:',ci)


if __name__=='__main__':unittest.main()
