#!/usr/bin/env bash
# Test pinentry auto-detection configuration

set -euo pipefail

echo "🔐 Testing Pinentry Configuration"
echo ""

# Check environment
echo "📍 Current Environment:"
echo "  DISPLAY: ${DISPLAY:-<not set>}"
echo "  WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<not set>}"
echo "  GPG_TTY: ${GPG_TTY:-<not set>}"
echo ""

# Check gpg-agent status
echo "🔧 GPG Agent Status:"
if gpg-connect-agent /bye >/dev/null 2>&1; then
    echo "  ✓ GPG agent is running"

    # Get agent info
    agent_info=$(gpg-connect-agent 'getinfo version' /bye 2>/dev/null | head -1)
    echo "  Version: $agent_info"
else
    echo "  ✗ GPG agent is not running"
    echo "  Starting agent..."
    gpgconf --launch gpg-agent
fi

echo ""

# Check pinentry configuration
echo "📝 Pinentry Configuration:"
pinentry_prog=$(gpgconf --list-options gpg-agent 2>/dev/null | grep '^pinentry-program:' | cut -d: -f10 || echo "")
if [ -n "$pinentry_prog" ]; then
    echo "  Program: $pinentry_prog"
    if [ -x "$pinentry_prog" ]; then
        echo "  ✓ Pinentry program is executable"
    else
        echo "  ✗ Pinentry program not found or not executable"
    fi
else
    echo "  ℹ Using default pinentry (home-manager config not applied yet)"
fi

echo ""

# Check available pinentry variants
echo "🔍 Available Pinentry Variants:"
for variant in pinentry-gnome3 pinentry-gtk2 pinentry-curses pinentry-auto; do
    if command -v $variant >/dev/null 2>&1; then
        location=$(command -v $variant)
        echo "  ✓ $variant"
        echo "    Location: $location"
        if [ "$variant" = "pinentry-auto" ]; then
            echo "    (This is the smart wrapper)"
        fi
    else
        echo "  ✗ $variant not found"
    fi
done

echo ""

# Predict which pinentry will be used
echo "🎯 Expected Pinentry Behavior:"
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo "  Mode: GUI (display detected)"
    if command -v pinentry-gnome3 >/dev/null 2>&1; then
        echo "  Will use: pinentry-gnome3"
    elif command -v pinentry-gtk2 >/dev/null 2>&1; then
        echo "  Will use: pinentry-gtk2"
    else
        echo "  Will use: pinentry-curses (GUI versions not found)"
    fi
else
    echo "  Mode: Console (no display)"
    echo "  Will use: pinentry-curses"
fi

echo ""
echo "💡 Test Commands:"
echo "  # Test with real GPG operation:"
echo "    echo 'test' | gpg --clearsign"
echo ""
echo "  # Force console mode (temporarily):"
echo "    env -u DISPLAY -u WAYLAND_DISPLAY gpg --clearsign"
echo ""
echo "  # Restart GPG agent:"
echo "    gpgconf --kill gpg-agent"
echo "    gpgconf --launch gpg-agent"
echo ""
echo "📚 Documentation: docs/PINENTRY_SETUP.md"
