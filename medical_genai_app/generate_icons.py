#!/usr/bin/env python3
"""Generate custom Medical GenAI app icons to replace default Flutter icons."""

from PIL import Image, ImageDraw, ImageFont
import math, os

EMERALD = (5, 150, 105)       # #059669
DARK_BG = (15, 23, 42)        # #0F172A  (slate-900)
WHITE = (255, 255, 255)
LIGHT_GREEN = (52, 211, 153)  # #34D399

def draw_medical_ai_icon(size, maskable=False):
    """Draw a medical AI themed icon at the given size."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    padding = int(size * 0.1) if maskable else 0
    safe = size - 2 * padding

    # Background - rounded rectangle (circle for small, rounded for large)
    if maskable:
        # Maskable: fill entire canvas
        draw.rectangle([0, 0, size, size], fill=DARK_BG)
    else:
        # Regular: rounded rectangle
        radius = int(size * 0.18)
        draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=DARK_BG)

    cx, cy = size // 2, size // 2

    # --- Outer ring (pulse/circle) ---
    ring_r = int(safe * 0.38)
    ring_w = max(int(size * 0.025), 2)
    draw.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=EMERALD, width=ring_w
    )

    # --- Inner filled circle ---
    inner_r = int(safe * 0.28)
    # Gradient-like effect: draw concentric circles
    for i in range(inner_r, 0, -1):
        t = i / inner_r
        r = int(EMERALD[0] * t + DARK_BG[0] * (1 - t) * 0.3)
        g = int(EMERALD[1] * t + DARK_BG[1] * (1 - t) * 0.3)
        b = int(EMERALD[2] * t + DARK_BG[2] * (1 - t) * 0.3)
        draw.ellipse(
            [cx - i, cy - i, cx + i, cy + i],
            fill=(r, g, b, 255)
        )

    # --- Medical cross (plus sign) ---
    cross_size = int(safe * 0.13)
    cross_thick = max(int(safe * 0.045), 2)
    # Vertical bar
    draw.rounded_rectangle(
        [cx - cross_thick, cy - cross_size, cx + cross_thick, cy + cross_size],
        radius=max(cross_thick // 2, 1),
        fill=WHITE
    )
    # Horizontal bar
    draw.rounded_rectangle(
        [cx - cross_size, cy - cross_thick, cx + cross_size, cy + cross_thick],
        radius=max(cross_thick // 2, 1),
        fill=WHITE
    )

    # --- AI neural dots around the ring ---
    num_dots = 8
    dot_r = max(int(size * 0.018), 2)
    dot_ring_r = int(safe * 0.38)
    for i in range(num_dots):
        angle = (2 * math.pi * i / num_dots) - math.pi / 2
        dx = cx + int(dot_ring_r * math.cos(angle))
        dy = cy + int(dot_ring_r * math.sin(angle))
        draw.ellipse(
            [dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r],
            fill=LIGHT_GREEN
        )

    # --- Small connection lines from dots toward center ---
    line_w = max(int(size * 0.01), 1)
    line_inner = int(safe * 0.30)
    for i in range(num_dots):
        angle = (2 * math.pi * i / num_dots) - math.pi / 2
        x1 = cx + int(dot_ring_r * math.cos(angle))
        y1 = cy + int(dot_ring_r * math.sin(angle))
        x2 = cx + int(line_inner * math.cos(angle))
        y2 = cy + int(line_inner * math.sin(angle))
        draw.line([(x1, y1), (x2, y2)], fill=(*LIGHT_GREEN, 120), width=line_w)

    # --- Heartbeat/pulse line across ---
    pulse_y = cy
    pulse_points = []
    pulse_start = cx - int(safe * 0.33)
    pulse_end = cx + int(safe * 0.33)
    pulse_w = pulse_end - pulse_start

    segments = 20
    for s in range(segments + 1):
        t = s / segments
        x = pulse_start + int(t * pulse_w)
        # Flat line with spike in the middle
        if 0.35 < t < 0.42:
            y = pulse_y - int(safe * 0.12 * ((t - 0.35) / 0.07))
        elif 0.42 <= t < 0.50:
            y = pulse_y + int(safe * 0.08 * ((t - 0.42) / 0.08))
        elif 0.50 <= t < 0.55:
            y = pulse_y - int(safe * 0.04 * ((0.55 - t) / 0.05))
        else:
            y = pulse_y
        pulse_points.append((x, y))

    # Draw the pulse but only outside the inner circle
    pulse_line_w = max(int(size * 0.015), 1)
    for i in range(len(pulse_points) - 1):
        x1, y1 = pulse_points[i]
        x2, y2 = pulse_points[i + 1]
        dist1 = math.sqrt((x1 - cx) ** 2 + (y1 - cy) ** 2)
        dist2 = math.sqrt((x2 - cx) ** 2 + (y2 - cy) ** 2)
        if dist1 > inner_r * 0.9 and dist2 > inner_r * 0.9:
            draw.line([(x1, y1), (x2, y2)], fill=LIGHT_GREEN, width=pulse_line_w)

    return img


def main():
    web_dir = os.path.join(os.path.dirname(__file__), 'web')
    icons_dir = os.path.join(web_dir, 'icons')

    sizes = {
        'favicon.png': (32, False),
        'icons/Icon-192.png': (192, False),
        'icons/Icon-512.png': (512, False),
        'icons/Icon-maskable-192.png': (192, True),
        'icons/Icon-maskable-512.png': (512, True),
    }

    for filename, (size, maskable) in sizes.items():
        icon = draw_medical_ai_icon(size, maskable=maskable)
        path = os.path.join(web_dir, filename)
        icon.save(path, 'PNG')
        print(f"✓ Generated {path} ({size}x{size}, maskable={maskable})")

    print("\nAll icons generated!")


if __name__ == '__main__':
    main()
