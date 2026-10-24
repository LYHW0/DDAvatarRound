import pathlib, unittest
S=(pathlib.Path(__file__).resolve().parents[1]/'Sources/LYHWGlassTabBar.x').read_text()
class SelectionTransition(unittest.TestCase):
    def test_provider_lifetime_not_visibility(self):
        self.assertIn('state.nativeProviderEstablished = YES',S)
        self.assertIn('BOOL nativeOwnsSelection = state.nativeProviderEstablished || nativeLensFound',S)
    def test_geometry_only_initial_or_resize(self):
        self.assertIn('if (pass.alignmentEstablished && !sizeChanged) return;',S)
    def test_presentation_not_final_model(self):
        self.assertIn('lens.layer.presentationLayer',S)
        self.assertIn('nativeGeometryStable ? nativeRect : CGRectNull',S)
    def test_no_fill_when_native_owns(self):
        self.assertIn('if (!nativeOwnsSelection && moved && sSlidingMask',S)
        self.assertIn('nativeOwnsSelection || !sCustomMaskRequested || !valid',S)
if __name__=='__main__': unittest.main()
