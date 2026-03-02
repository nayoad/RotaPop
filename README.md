# RotaPop

A lightweight, Midnight-ready WoW AddOn that suggests your next rotation action based on a SimC APL.

## Features
- SimC APL parser (no external dependencies)
- Clean Midnight (12.x) API usage only
- Subtlety Rogue support (TWW S2 APL)
- Minimal single-icon UI

## Commands
- `/rotapop` – toggle on/off

## Adding Specs
Add a new file to `Spells/` and register your action lists via `APL:RegisterList()`.
