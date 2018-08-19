# -*- coding: utf-8 -*-

import pyroute2

from .gateway import Gateway


class Network(object):

    def __init__(self, network_id):
        self.network_id = network_id
        self.if_name = "vcan{}".format(network_id[:8])
        self.endpoints = {}
        self.gateway = Gateway()

    def create_resource(self):
        with pyroute2.IPDB() as ipdb:
            with ipdb.create(kind='vcan', ifname=self.if_name) as link:
                link.up()

    def delete_resource(self):
        with pyroute2.IPDB() as ipdb:
            with ipdb.interfaces[self.if_name] as link:
                link.down()
                link.remove()

    def add_endpoint(self, endpoint):
        self.endpoints[endpoint.endpoint_id] = endpoint

    def remove_endpoint(self, endpoint_id):
        return self.endpoints.pop(endpoint_id)

    def attach_endpoint(self, endpoint_id, namespace_id):
        endpoint = self.endpoints[endpoint_id]
        endpoint.attach(namespace_id)
        self.gateway.add_rule(self.if_name, endpoint.if_name)
        self.gateway.add_rule(endpoint.if_name, self.if_name)
        for other_id, other in self.endpoints.items():
            if other_id != endpoint_id:
                self.gateway.add_rule(other.if_name, endpoint.if_name)
                self.gateway.add_rule(endpoint.if_name, other.if_name)

    def detach_endpoint(self, endpoint_id):
        endpoint = self.endpoints[endpoint_id]
        for other_id, other in self.endpoints.items():
            if other_id != endpoint_id:
                self.gateway.remove_rule(other.if_name, endpoint.if_name)
                self.gateway.remove_rule(endpoint.if_name, other.if_name)
        self.gateway.remove_rule(endpoint.if_name, other.if_name)
        self.gateway.remove_rule(other.if_name, endpoint.if_name)
        endpoint.detach()
