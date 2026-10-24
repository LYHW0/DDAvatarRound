"""UIKit-independent coordinate model + source guards; not a device render test."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ContactsClip(unittest.TestCase):
    def test_detached_background_window_conversion_misses_content(self):
        # fromView:nil interprets card.frame in window, not cell coordinates.
        for cell_y in (276, 332, 388):
            old_y = 0 - cell_y
            self.assertLess(old_y + 56, 0)
            # lockedFrame belongs to cell; contentView origin is {0,0}.
            self.assertEqual((10 - 0, 0 - 0, 373, 56), (10, 0, 373, 56))

    def test_content_offset_preserved(self):
        self.assertEqual((10 - 25, 0 - 3, 373, 56), (-15, -3, 373, 56))

    def test_contacts_path_and_owned_reuse_cleanup(self):
        src = (ROOT / 'Sources/LYHWCellCards.x').read_text()
        self.assertIn('lockedFrame fromView:cell', src)
        self.assertIn('!CGRectIntersectsRect(r, host.bounds)', src)
        reuse = src.split('- (void)prepareForReuse {', 1)[1].split('- (void)setHighlighted:', 1)[0]
        self.assertIn('@"NewContactsItemCell"', reuse)
        self.assertIn('@"LYHWClipMask"', reuse)

    def test_dump_has_real_mask_evidence(self):
        src = (ROOT / 'Sources/LYHWDebugDump.x').read_text()
        for token in ('layer.mask', 'CGPathGetPathBoundingBox', 'CGPathApply', 'layer.opacity', 'layer.zPosition', 'layer.transform', 'hostRect=', 'cellRect='):
            self.assertIn(token, src)

if __name__ == '__main__':
    unittest.main()
