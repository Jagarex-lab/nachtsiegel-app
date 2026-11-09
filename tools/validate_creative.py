#!/usr/bin/env python3
"""Validate editorial references, localization, draft boundaries and frozen gameplay data."""
import json,re
from pathlib import Path
from sync_brand import release_name,expected_files
from render_narrative import generate
ROOT=Path(__file__).resolve().parents[1]
assertions=0
def check(value,why):
    global assertions
    assertions+=1
    if not value:raise AssertionError(why)
def read(path):return json.loads((ROOT/path).read_text())
def main():
    m=read('data/narrative/content.json');de=read('data/narrative/locales/de.json');en=read('data/narrative/locales/en.json');c=m['collections']
    check(m['schema_version']==1 and m['status']=='creative_draft' and not m['runtime_enabled'],'Draft is not runtime content')
    check(set(de)==set(en),'Complete DE/EN key parity')
    ids=set();used={m['work_title_key'],m['opening_key'],'preview.notice','preview.greeting'}
    counts={'world':1,'timeline':6,'paths':5,'factions':4,'locations':8,'characters':10,'cards':20,'intro':5,'chapters':5,'campaign':1,'boss':1,'secrets':5,'arcs':3}
    check(set(c)==set(counts),'Declared collections')
    for group,count in counts.items():
        check(len(c[group])==count,'Count '+group)
        for item in c[group]:
            check(bool(re.fullmatch('[a-z][a-z0-9_]*',item['id'])),'Stable ID syntax')
            check(item['id'] not in ids,'Unique ID '+item['id']);ids.add(item['id'])
            for field,key in item['texts'].items():
                check(key.startswith(group+'.'+item['id']+'.'),'Namespaced key '+key)
                check(key in de and key in en,'Resolved localized field '+key);used.add(key)
    check(used==set(de),'No orphan text or missing editorial key')
    for key in de:
        for locale,strings in [('de',de),('en',en)]:
            check(isinstance(strings[key],str) and strings[key].strip()!='','Nonempty '+locale+' '+key)
            check(not any(t in strings[key]for t in ['TODO','TBD','Lorem ipsum']),'No placeholder prose '+key)
        check(set(re.findall(r'\{([^{}]+)\}',de[key]))==set(re.findall(r'\{([^{}]+)\}',en[key])),'Placeholder parity '+key)
    factions={i['id']for i in c['factions']}|{'independent'}
    characters={i['id']for i in c['characters']};locations={i['id']for i in c['locations']};chapters={i['id']for i in c['chapters']}
    check([i['lane_index']for i in c['paths']]==list(range(5)),'Five paths retain original indices')
    check(sorted(s for f in c['factions']for s in f['legacy_sigils'])==['ASH','THORN','TIDE','VEIL'],'Four legacy visual identities')
    check(sum(i['hero_candidate']for i in c['characters'])==6,'Six hero concepts')
    for i in c['characters']+c['cards']:check(i['faction_id']in factions,'Faction reference '+i['id'])
    for i in c['chapters']:
        check(i['location_id']in locations,'Chapter location')
        check(set(i['character_ids'])<=characters,'Chapter characters')
        check(i['antagonist_id']is None or i['antagonist_id']in characters,'Chapter antagonist')
        check(i['status']=='narrative_design_only','No implemented campaign claim')
    for i in c['secrets']:check(set(i['reveal_chapter_ids'])<=chapters,'Spoiler reveal references')
    check(c['campaign'][0]['chapter_ids']==[i['id']for i in c['chapters']],'Ordered five-chapter campaign')
    check(c['campaign'][0]['id']==m['campaign_id'],'Campaign reference')
    boss=c['boss'][0]
    check(boss['status']=='design_only_not_implemented' and boss['ruleset']=='existing_duel','Boss is a bounded narrative design')
    check(boss['character_id']in characters and boss['chapter_id']=='chapter_01','First boss narrative references')
    check(boss['opponent_pool_indices']==list(range(6)),'No faction deck override or AI rule change')
    baseline=read('tests/fixtures/legacy_card_pool.json')
    s=(ROOT/'data/card_definitions.gd').read_text();active=json.loads(re.search(r'const POOL := (\[.*?\n\])',s,re.S).group(1))
    check(active==baseline,'Frozen card names, stats, effects and identities unchanged')
    bindings=[i for i in c['cards']if i['status']=='existing_presentation_binding']
    check([i['legacy_pool_index']for i in bindings]==list(range(7)),'Exactly seven existing bindings')
    for i in c['cards']:
        check(i['flavor_only']and not ({'cost','attack','hp','effect'}&set(i)),'Flavor introduces no combat stats')
        if i in bindings:check(i['legacy_name']==baseline[i['legacy_pool_index']]['name'],'Stable legacy name')
        else:check(i['status']=='concept_only'and 'legacy_pool_index'not in i,'New cards not silently playable')
        for t in [de,en]:check(len(t[i['texts']['flavor']].split())<=22,'Short card flavor '+i['id'])
    check(len(bindings)==7 and len(c['cards'])-len(bindings)==13,'Existing and concept card split')
    for language,t in [('de',de),('en',en)]:
        check(140<=len(t[m['opening_key']].split())<=165,'Approximately 150-word opening '+language)
        spoken=sum(len(t[i['texts']['voice']].split())for i in c['intro'])
        check(45<=spoken<=90,'Short intro voice, room for pauses '+language)
    end=0
    for i in c['intro']:
        check(i['start_seconds']==end and i['end_seconds']>end,'Continuous intro timeline');end=i['end_seconds']
        check(i['speaker_id']in characters,'Intro speaker')
    check(end==m['intro_duration_seconds']and 30<=end<=45,'30–45 second intro')
    brand=read('data/brand/identity.json')
    check(release_name(brand)=='NACHTSIEGEL' and brand['approved_product_name']is None,'No unapproved product rename')
    check(brand['approval_reference']is None,'No fabricated name approval')
    for language in ['de','en']:check('ARBEITSTITEL' in brand['preview'][language]or 'WORKING TITLE'in brand['preview'][language],'Labeled preview '+language)
    rejected=False
    try:release_name({**brand,'approved_product_name':'KERUVANT'})
    except ValueError:rejected=True
    check(rejected,'Unapproved promotion is rejected')
    for path,expected in expected_files().items():check(path.read_text()==expected,'Synchronized release metadata '+path.name)
    for name,expected in generate().items():check((ROOT/'docs/creative'/name).read_text()==expected,'Generated bible '+name)
    print(f'CREATIVE DATA: {assertions} assertions, 0 failures; 74 entities; {len(de)} keys per locale; unchanged 7-card pool')
if __name__=='__main__':main()
