from pathlib import Path
import unittest
R=Path(__file__).resolve().parents[1]
class LiquidIntegration(unittest.TestCase):
 def test_single_engine(self):
  self.assertFalse((R/'Sources/LYHWGlassTabBar.x').exists())
  self.assertTrue((R/'Sources/LYHWGlassTabBar.m').exists())
 def test_preserve_settings(self):
  t=(R/'Sources/LYHWGlassTabBar.m').read_text()
  for key in ['glassTabBarEnabled','glassHideRedDot','glassHideBadge','com.lyhw.LYHW','LYHWSettingsChangedNotification','LQRefreshWC();']:
   self.assertIn(key,t)
 def test_abi_and_runtime(self):
  t=(R/'Sources/LYHWGlassTabBar.m').read_text()
  self.assertIn('typedef void (*LQLGRelayoutIMP)(id, SEL, id);',t)
  self.assertIn('method_setImplementation(inherited, replacement)',t)
  self.assertNotIn('MSHookMessageEx(cls',t)
 def test_stable_native_selection(self):
  t=(R/'Sources/WCBridge.inc').read_text()
  self.assertEqual(t.count('setItems:items'),1)
  self.assertIn('if(initial) [self.nativeBar setItems:items animated:NO]',t)
  self.assertIn('object_getClass(owner),selected',t)
  self.assertIn('NSUInteger index=NSNotFound',t)
  self.assertIn('dotBadge && sHideRedDot',t)
  self.assertIn('!dotBadge && sHideBadge',t)
 def test_speed_entry_kept(self):
  t=(R/'Sources/LYHWPluginUI.m').read_text()
  self.assertIn('LYHWItem(L63Decode(169), L63Decode(151), L63Decode(151)',t)
if __name__=='__main__': unittest.main()
