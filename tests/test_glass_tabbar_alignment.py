"""Dump geometry model + source guards; UIKit device validation still required."""
import pathlib
import unittest

SOURCE = (pathlib.Path(__file__).resolve().parents[1] / 'Sources/LYHWGlassTabBar.x').read_text()


def target_centers(platter, item_width, item_height, content_min_y, content_max_y):
    x, y, w, h = platter
    return [(x + w * (i + .5) / 4,
             item_height / 2 + y + h / 2 - (content_min_y + content_max_y) / 2)
            for i in range(4)]


class GlassAlignment(unittest.TestCase):
    def test_real_dump_wide_label_safe_area_tail(self):
        # 98x90 item; UILabel frame=(0,38,98,12), actual title ink 24pt;
        # MMWebImageView icon y=7..35. Native platter=(21,7,351,62).
        centers = target_centers((21, 7, 351, 62), 98, 90, 7, 50)
        self.assertEqual([p[0] for p in centers], [64.875, 152.625, 240.375, 328.125])
        self.assertTrue(all(p[1] == 54.5 for p in centers))
        self.assertLess(24, 351 / 4)
        self.assertGreater(98, 351 / 4)  # full label width must not veto alignment
        self.assertIn('textRectForBounds:title.bounds', SOURCE)
        self.assertIn('isEqualToString:@"MMWebImageView"', SOURCE)
        self.assertIn('CGRectGetMidX(item.bounds), CGRectGetMidY(content)', SOURCE)

    def test_idempotent_actual_content_center(self):
        centers = target_centers((21, 7, 351, 62), 98, 90, 7, 50)
        for _, cy in centers:
            self.assertEqual(cy - 45 + (7 + 50) / 2, 38)
        self.assertIn('>= 0.5', SOURCE)
        self.assertIn('LYHWGlassBadgeName(NSStringFromClass(child.class))', SOURCE)

    def test_other_bar_sizes_not_screen_constants(self):
        for p in [(15, 5, 290, 58), (30, 9, 600, 70)]:
            centers = target_centers(p, 98, 90, 7, 50)
            self.assertAlmostEqual(centers[-1][0] - centers[0][0], p[2] * .75)
        self.assertNotIn('UIScreen', SOURCE)

    def test_async_object_guard_and_oscillation_fuse(self):
        self.assertIn('pass.queued || pass.inPass', SOURCE)
        self.assertIn('pass.alignmentWrites >= 4', SOURCE)
        self.assertIn('pass.alignmentSuspended = YES', SOURCE)
        self.assertIn('sWCLGLayoutDepth > 0', SOURCE)
        self.assertNotIn('sWCLGPendingBar', SOURCE)
        layout = SOURCE.split('static void WCLGTabLayoutSubviews', 1)[1].split('static void WCLGTabDidMoveToWindow', 1)[0]
        self.assertNotIn('LYHWGlassAlignTabBarItems', layout)
        self.assertIn('WCLGSchedulePass', layout)

    def test_native_lens_not_painted_over(self):
        self.assertIn('BOOL hideMask = nativeLensFound ||', SOURCE)
        self.assertNotIn('removeFromSuperview', SOURCE)
        self.assertNotIn('layoutIfNeeded', SOURCE.replace('// No layoutIfNeeded/setNeedsLayout', ''))
        self.assertIn('effect.tag != 102289', SOURCE)
        self.assertIn('if (!sWCLGEnabled) return; // Absolutely no hooks', SOURCE)


if __name__ == '__main__':
    unittest.main()
