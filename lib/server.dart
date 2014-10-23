library communicator_server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'carrier.dart';

export 'package:route/server.dart';

typedef Future<bool> WSFilter();

Future doWhile(Iterable iterable, Future<bool> action(i)) =>
    _doWhile(iterable.iterator, action);

Future _doWhile(Iterator iterator, Future<bool> action(i)) =>
    (iterator.moveNext())
        ? action(iterator.current).then((bool result) =>
            (result)
                ? _doWhile(iterator, action)
                : new Future.value(false))
        : new Future.value(false);

bool matchesFull(Pattern pattern, String str) {
    var iter = pattern.allMatches(str).iterator;
    if (iter.moveNext()) {
        var match = iter.current;
        return match.start == 0
        && match.end == str.length
        && !iter.moveNext();
    }
    return false;
}

class Client {

    static List<Client> instances = new List();

    HttpRequest req;

    final WebSocket ws;

    Client(this.ws, [this.req]) {
        instances.add(this);
    }

    write(String data) => ws.add(data);

    send(String controller, dynamic data) => ws.add(new Carrier(controller).formMessage(data));

    static remove(Client client) {
        client.ws.close();
        instances.remove(client);
    }

}

class WSRequest {

    Carrier carrier;

    Client client;

    Uri uri;

    WSRequest(String json, this.client) {
        carrier = new Carrier.fromData(json);
        uri = new Uri(path:carrier.controller);
    }

    get controller => carrier.controller;

    get message => carrier.message;

    get session => client.req.session;

    get req => client.req;

    write(dynamic data) => client.write(carrier.formMessage(data));

}

class WSRouter {

    final Client _incoming;

    final List<_WSRoute> _routes = <_WSRoute>[];

    final Map<Pattern, WSFilter> _filters = new LinkedHashMap<Pattern, WSFilter>();

    final StreamController<WSRequest> _defaultController = new StreamController<WSRequest>();

    WSRouter(WebSocket incoming, [HttpRequest req]) : _incoming = new Client(incoming, req) {
        _incoming.ws.map((json) => new WSRequest(json, _incoming))
        .listen(_handleRequest, onError: (_) => Client.remove(_incoming), onDone: () => Client.remove(_incoming));
    }

    Stream<WSRequest> serve(Pattern url, {method}) {
        var controller = new StreamController<WSRequest>();
        _routes.add(new _WSRoute(controller, url));
        return controller.stream;
    }

    void filter(Pattern url, WSFilter filter) {
        _filters[url] = filter;
    }

    Stream<WSRequest> get defaultStream => _defaultController.stream;

    void _handleRequest(WSRequest req) {
        bool cont = true;
        doWhile(_filters.keys, (Pattern pattern) {
            if (matchesFull(pattern, req.controller)) {
                return _filters[pattern](req).then((c) {
                    cont = c;
                    return c;
                });
            }
            return new Future.value(true);
        }).then((_) {
            if (cont) {
                bool handled = false;
                var matches = _routes.where((r) => r.matches(req));
                if (!matches.isEmpty) {
                    matches.first.controller.add(req);
                } else {
                    if (_defaultController.hasListener) {
                        _defaultController.add(req);
                    } else {
                        req.write('Not Found');
                    }
                }
            }
        });
    }
}

class _WSRoute {
    final Pattern url;
    final StreamController controller;
    _WSRoute(this.controller, this.url);

    bool matches(WSRequest request) => matchesFull(url, request.controller);
}