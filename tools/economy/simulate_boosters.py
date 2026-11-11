#!/usr/bin/env python3
"""Standalone booster Monte Carlo; full run is simulate_progression.py."""
import argparse, json
from model import load_config
from simulate_progression import OUT, booster_trials
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--packs',type=int,default=100000);p.add_argument('--seed',type=int,default=14502026);a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    print(json.dumps(booster_trials(load_config(),a.packs,a.seed),indent=2))
