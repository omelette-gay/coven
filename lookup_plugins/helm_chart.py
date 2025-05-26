import os
import yaml

from ansible.plugins.lookup import LookupBase


class LookupModule(LookupBase):
    def run(self, terms, variables=None, **kwargs):
        return [
            {"version": dependency["version"], "repository": dependency["repository"]}
            for dependency in self._load_chart_yaml().get("dependencies", [])
            if dependency.get("name") in terms
        ]

    def _load_chart_yaml(self):
        chart_contents, _ = self._loader._get_file_contents(os.path.join(os.path.dirname(__file__), os.pardir, "Chart.yaml"))
        return yaml.safe_load(chart_contents)
