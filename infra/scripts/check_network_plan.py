"""Fail closed on service mutations; print only sanitized what-if counts."""

import json
import sys
from collections import Counter


ALLOWED_TYPES = {
    'microsoft.resources/deployments',
    'microsoft.network/networksecuritygroups',
    'microsoft.network/virtualnetworks',
    'microsoft.network/privatednszones',
    'microsoft.network/privatednszones/virtualnetworklinks',
    'microsoft.network/dnsresolvers',
    'microsoft.network/dnsresolvers/inboundendpoints',
    'microsoft.network/privateendpoints',
    'microsoft.network/privateendpoints/privatednszonegroups',
    'microsoft.network/publicipaddresses',
    'microsoft.network/virtualnetworkgateways',
    'microsoft.insights/diagnosticsettings',
    'microsoft.operationalinsights/workspaces',
}


def check_template(template):
    """Inspect declarations recursively, including nested ARM deployments."""
    def visit(value):
        if isinstance(value, dict):
            if 'publicNetworkAccess' in value:
                raise ValueError('Network template must not change public access')
            if 'resources' in value:
                resources = value['resources']
                if not isinstance(resources, list):
                    raise ValueError('Unexpected ARM resource collection')
                for resource in resources:
                    if resource.get('type', '').lower() not in ALLOWED_TYPES:
                        raise ValueError('Unexpected resource declaration; review ownership')
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    visit(template)
    if template['parameters']['deployVpn']['defaultValue'] is not False:
        raise ValueError('VPN must remain opt-in')
    if template['parameters']['endpoints']['defaultValue'] != []:
        raise ValueError('Service endpoints must remain opt-in')


def check_plan(plan):
    if plan.get('status') != 'Succeeded' or plan.get('error'):
        raise ValueError('Azure what-if did not succeed')
    changes = plan.get('changes')
    if not isinstance(changes, list):
        raise ValueError('Missing Azure what-if changes')
    counts = Counter()
    for change in changes:
        kind = change.get('changeType')
        if kind not in {'Create', 'NoChange', 'Ignore'}:
            raise ValueError('Non-additive or unresolved change detected; inspect privately before proceeding')
        if kind == 'Create':
            resource_type = change.get('after', {}).get('type', '').lower()
            if resource_type not in ALLOWED_TYPES:
                raise ValueError('Unexpected new resource type; inspect privately')
        counts[kind] += 1
    return counts


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in {'template', 'plan'}:
        sys.exit('Usage: check_network_plan.py template|plan FILE')
    try:
        with open(sys.argv[2], encoding='utf-8-sig') as source:
            data = json.load(source)
        if sys.argv[1] == 'template':
            check_template(data)
            print('Compiled-template safety checks passed.')
        else:
            counts = check_plan(data)
            print('Azure what-if passed: ' + ', '.join(f'{key}={counts[key]}' for key in sorted(counts)))
            print('No modifications, deletions or unresolved changes. No live connectivity validation implied.')
    except (ValueError, KeyError, TypeError) as exc:
        sys.exit(str(exc))
