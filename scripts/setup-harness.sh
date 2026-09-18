#!/usr/bin/env bash
# ==============================================================================
# setup-harness.sh — Automatisches Setup für Claude Code Plugins & AppStore Harness
# ==============================================================================
# Installiert die offiziellen Open-Source-Plugins (Superpowers & ECC) und verlinkt
# die projektspezifischen AppStore-Flows (/user-story, /harness-workflow).
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 Starte Harness-Setup für DHBW AppStore..."

# 1. Voraussetzungen prüfen
if ! command -v claude &>/dev/null; then
    echo "❌ Fehler: 'claude' CLI ist nicht installiert."
    echo "   Installiere Claude Code via: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

echo "✅ Claude Code CLI gefunden: $(claude --version)"

# 2. Marketplaces hinzufügen
echo ""
echo "📦 Konfiguriere Plugin-Marketplaces..."
claude plugin marketplace add obra/superpowers-marketplace || true
claude plugin marketplace add https://github.com/affaan-m/ECC || true

# 3. Offizielle Open-Source Plugins installieren
echo ""
echo "⚡ Installiere offizielle Plugins (Superpowers & ECC)..."
claude plugin install superpowers@superpowers-marketplace || true
claude plugin install ecc@ecc || true

# 4. Alte / kollidierende Symlinks bereinigen
echo ""
echo "🧹 Bereinige veraltete Skill-Symlinks..."
rm -f ~/.claude/skills/tdd ~/.claude/skills/systematic-debugging ~/.claude/agents/code-reviewer.md 2>/dev/null || true

# 5. AppStore Custom Flows verlinken
echo ""
echo "🔗 Verlinke DHBW-AppStore Projekt-Flows..."
mkdir -p ~/.claude/skills
ln -sfn "$REPO_ROOT/.claude/skills/user-story" ~/.claude/skills/user-story
ln -sfn "$REPO_ROOT/.claude/skills/harness-workflow" ~/.claude/skills/harness-workflow

echo ""
echo "=================================================================="
echo "🎉 Setup erfolgreich abgeschlossen!"
echo "=================================================================="
echo "Aktive Plugins:"
claude plugin list

echo ""
echo "Verfügbare AppStore-Flows in ~/.claude/skills/:"
ls -la ~/.claude/skills
echo ""
echo "Du kannst jetzt in Claude Code arbeiten mit:"
echo "  - /user-story                (Flow 1: Feature-Klärung & Spec)"
echo "  - /harness-workflow          (Flow 2: Issue -> TDD -> Dev -> Staging)"
echo "  - /superpowers:...           (Offizielle Superpowers TDD & Debugging Tools)"
echo "  - /code-review (oder Agent)  (Offizieller ECC Code Reviewer)"
