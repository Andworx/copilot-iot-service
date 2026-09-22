"""Safety gate regressions: a preview must not authorize destructive changes."""

import unittest

from check_network_plan import check_plan, check_template


class NetworkPlanTests(unittest.TestCase):
    def test_additive_preview(self):
        result = check_plan({'status': 'Succeeded', 'changes': [
            {'changeType': 'Create', 'after': {'type': 'Microsoft.Network/virtualNetworks'}},
            {'changeType': 'Ignore'},
            {'changeType': 'NoChange'},
        ]})
        self.assertEqual(result['Create'], 1)

    def test_reject_changes_and_unresolved_previews(self):
        for kind in ['Delete', 'Modify', 'Deploy', 'Unsupported', None]:
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                check_plan({'status': 'Succeeded', 'changes': [{'changeType': kind}]})

    def test_reject_existing_service_creation(self):
        with self.assertRaises(ValueError):
            check_plan({'status': 'Succeeded', 'changes': [
                {'changeType': 'Create', 'after': {'type': 'Microsoft.Web/sites'}},
            ]})

    def test_reject_failed_or_malformed_preview(self):
        for plan in [{}, {'status': 'Failed', 'changes': []}, {'status': 'Succeeded'}]:
            with self.subTest(plan=plan), self.assertRaises(ValueError):
                check_plan(plan)

    def test_reject_nested_service_and_firewall_declarations(self):
        for resource in [
            {'type': 'Microsoft.Web/sites'},
            {'type': 'Microsoft.Network/virtualNetworks', 'properties': {'publicNetworkAccess': 'Disabled'}},
        ]:
            with self.subTest(resource=resource), self.assertRaises(ValueError):
                check_template({'resources': [
                    {'type': 'Microsoft.Resources/deployments', 'properties': {'template': {'resources': [resource]}}},
                ]})


if __name__ == '__main__':
    unittest.main()
