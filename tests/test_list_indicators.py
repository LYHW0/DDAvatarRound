import pathlib, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class ListIndicators(unittest.TestCase):
    def test_scoped_to_recognized_tables(self):
        s=(ROOT/'Sources/LYHWCellCards.x').read_text()
        self.assertIn('- (void)setShowsVerticalScrollIndicator:(BOOL)show',s)
        self.assertIn('if (show && LYHWPageKind((UIView *)self) != 0) show = NO;',s)
        self.assertIn('%orig(show);',s)
    def test_no_global_scrollview_hook(self):
        s=(ROOT/'Sources/LYHWCellCards.x').read_text()
        self.assertNotIn('%hook UIScrollView',s)
        self.assertNotIn('scrollEnabled = NO',s)
if __name__ == '__main__': unittest.main()
