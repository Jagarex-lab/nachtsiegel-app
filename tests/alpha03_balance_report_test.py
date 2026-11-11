import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('alpha03_balance_report', Path(__file__).resolve().parents[1] / 'tools/alpha03/report_balance.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class IntegrityTests(unittest.TestCase):
    def report(self):
        games = []
        for pair in range(14):
            for level in (1,5):
                for first in ('hero','enemy'):
                    games.append({'index':len(games),'hero':f'a{pair}','enemy':f'b{pair}','winner':first,'first':first,'difficulty':level,'error':'','censored':False,'action_limit_reached':0,'convergence':False,'round':20,'event_sha256':'0'*64,'final_state_sha256':'1'*64})
        return {'games':games,'failures':0,'matrix_games':56,'total_actual_games':60,'verification_games':[{'index':i,'event_sha256':'0'*64,'final_state_sha256':'1'*64} for i in (0,7,32,55)]}

    def test_valid_structural_shape(self):
        summary = MODULE.summarize(self.report())
        self.assertEqual(summary['matrix_games'],56)
        self.assertEqual(summary['first_wins'],56)

    def test_missing_game_rejected(self):
        report = self.report();report['games'].pop()
        with self.assertRaises(ValueError):MODULE.summarize(report)

    def test_unfinished_game_rejected(self):
        report = self.report();report['games'][0]['censored']=True
        with self.assertRaises(ValueError):MODULE.summarize(report)

    def test_changed_first_side_rejected(self):
        report=self.report();report['games'][0]['first']='enemy'
        with self.assertRaises(ValueError):MODULE.summarize(report)

    def test_missing_replay_rejected(self):
        report=self.report();report['verification_games'].pop()
        with self.assertRaises(ValueError):MODULE.summarize(report)

    def test_altered_replay_rejected(self):
        report=self.report();report['verification_games'][0]['event_sha256']='f'*64
        with self.assertRaises(ValueError):MODULE.summarize(report)

    def test_engine_error_rejected(self):
        report=self.report();report['games'][0]['error']='queue_limit'
        with self.assertRaises(ValueError):MODULE.summarize(report)


if __name__=='__main__':unittest.main()
