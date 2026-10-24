"""Timing/ownership model + source guards; actual UIKit rendering needs device CI."""
import pathlib
import re
import unittest

SOURCE = (pathlib.Path(__file__).resolve().parents[1] / 'Sources/LYHWGlassTabBar.x').read_text()
NAV = SOURCE.split('#pragma mark - Right bar button shared background', 1)[1].split('void LYHWGlassTabBarRefresh', 1)[0]


def body(name):
    return NAV.split('static void ' + name + '(', 1)[1].split('\n}', 1)[0]


class Button:
    def __init__(self, hidden=False):
        self.hidden = hidden
        self.saved = None
        self.owner = None
        self.writes = 0

    def prepare(self, owner, root):
        if not root and self.saved is None:
            return
        self.owner = owner
        if root and self.saved is None:
            self.saved = self.hidden
        target = True if root else self.saved
        if self.hidden != target:
            self.hidden = target
            self.writes += 1
        if not root:
            self.saved = None

    def refresh_root(self, owner):
        if self.owner is None or self.owner == owner:
            self.prepare(owner, True)


class GlassNavTiming(unittest.TestCase):
    def test_all_button_setters_prepare_before_original(self):
        for suffix in ('RightItems', 'RightItemsAnimated', 'RightItem', 'RightItemAnimated'):
            b = body('LYHWGlass' + suffix)
            self.assertLess(b.index('LYHWGlassPrepareButtons'), b.index('sGlassOrig'))
        for selector in ('setRightBarButtonItems:', 'setRightBarButtonItems:animated:',
                         'setRightBarButtonItem:', 'setRightBarButtonItem:animated:'):
            self.assertIn('UINavigationItem.class, ' + selector + ',', NAV)

    def test_stack_and_layout_prepare_before_original(self):
        for suffix in ('NavItems', 'NavItemsAnimated', 'NavPush', 'NavLayout'):
            b = body('LYHWGlass' + suffix)
            self.assertLess(b.index('LYHWGlassPrepareNav'), b.index('sGlassOrig'))
        self.assertIn('setItems:animated:', NAV)
        self.assertIn('pushNavigationItem:animated:', NAV)

    def test_first_navigation_item_access_registers_structural_root(self):
        self.assertIn('UIViewController.class, navigationItem,', NAV)
        self.assertIn('LYHWGlassIsRootController(self)', NAV)
        self.assertIn('nav.viewControllers.firstObject != vc', NAV)
        self.assertIn('[tabs.viewControllers containsObject:nav]', NAV)
        self.assertIn('@"MMTabBarController"', NAV)
        self.assertIn('WCLGIsTabBarHookTarget(tabs.tabBar)', NAV)
        self.assertNotIn('nav.topItem != nav.items.firstObject', NAV)

    def test_no_async_restore_visibility_or_layout_request(self):
        for token in ('dispatch_after', 'dispatch_async', 'setNeedsLayout', 'layoutIfNeeded',
                      '.window', '.hidden', 'setHidden:', 'setAlpha:'):
            self.assertNotIn(token, NAV)
        self.assertIn('if (current != target)', NAV)
        self.assertIn('sGlassNavOriginals objectForKey:button', NAV)
        self.assertIn('owner && owner != item', NAV)

    def test_independent_originals_and_retry_safe_hook_helper(self):
        hooks = re.findall(r'^    LYHW_NAV_HOOK\([^\n]*, (sGlassOrig\w+)\);', NAV, re.M)
        self.assertEqual(len(hooks), 9)
        self.assertEqual(len(set(hooks)), 9)
        self.assertIn('if (original && *original) return YES;', SOURCE)
        self.assertIn('static Class installedClass;', NAV)
        self.assertIn('installedClass ?: NSClassFromString', NAV)
        self.assertIn('if (!sWCLGEnabled) return; // Absolutely no hooks', SOURCE)

    def test_no_global_item_property_hook_or_action_mutation(self):
        self.assertNotIn('LYHW_NAV_HOOK(UIBarButtonItem.class', NAV)
        self.assertNotIn('setAction:', NAV)
        self.assertNotIn('setTarget:', NAV)
        self.assertNotIn('customView', NAV)
        self.assertIn('weakToWeakObjectsMapTable', NAV)
        self.assertIn('weakObjectsHashTable', NAV)

    def test_new_button_hidden_before_original_observes_it(self):
        b = Button()
        b.prepare('root', True)
        original_observations = [b.hidden]
        self.assertEqual(original_observations, [True])

    def test_repeated_layout_is_difference_only(self):
        b = Button()
        for _ in range(100):
            b.refresh_root('root')
        self.assertEqual(b.writes, 1)
        self.assertFalse(b.saved)

    def test_tab_detach_and_push_do_not_restore(self):
        b = Button()
        b.prepare('root', True)
        for _ in ('tab detached', 'tab hidden', 'push', 'pop', 'tab return'):
            b.refresh_root('root')
            self.assertTrue(b.hidden)
        self.assertEqual(b.writes, 1)

    def test_chat_button_untouched(self):
        b = Button()
        b.prepare('chat', False)
        self.assertFalse(b.hidden)
        self.assertEqual(b.writes, 0)
        self.assertIsNone(b.owner)

    def test_explicit_chat_reuse_restores_without_stale_root_fight(self):
        for initial in (False, True):
            b = Button(initial)
            b.prepare('root', True)
            b.prepare('chat', False)
            self.assertEqual(b.hidden, initial)
            b.refresh_root('root')  # stale rightBarButtonItems array
            self.assertEqual(b.hidden, initial)
            b.prepare('root', True)  # explicit reassignment back to root
            self.assertTrue(b.hidden)


if __name__ == '__main__':
    unittest.main()
