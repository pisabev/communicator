library communicator_client;

import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:route/client.dart';
export 'package:route/client.dart';

/*
    loadingRequest = (cl.CJSElement loading) {
        var load_el;
        var timer = new Timer(new Duration(milliseconds:100), () => load_el = new cl.LoadElement(loading != null? loading : new cl.CJSElement(document.body)));
        return ([data, callback]) {
            if(data != null && callback != null) {
                if(data['data'] != null)
                    callback(data['data']);
                if(data['status'] != null)
                    new cl_app.Messager(ap, data['status']).show();
            }
            timer.cancel();
            if(load_el != null)
                load_el.remove();
        };
    };

class Loader {

    Timer timer;

    Loader();

    _stopTimer() => timer.cancel();

    start(loading) => timer = new Timer(new Duration(milliseconds:100), () => loading());

    end(data, callback) {
        timer.cancel();
        callback(data);
    }

}
*/

class Communicator {

    static Communicator _instance;

    WebsocketService ws;

    String path;

    Function _call;

    Function loadingRequest = (_) => null;

    factory Communicator([String path]) {
        if (_instance == null || path != null)
            _instance = new Communicator._(path);
        return _instance;
    }

    Communicator._(this.path) {
        _call = _callAjax;
    }

    Future upgrade(path_ws, Function on_server_call) {
        ws = new WebsocketService(path_ws);
        ws.controller.stream.listen(on_server_call);
        return ws.connect().then((_) => _call = _callWS);
    }

    Future call(contr, Map data, dynamic loading) {
        Completer completer = new Completer();
        _call(contr, data, completer.complete, loading);
        return completer.future;
    }

    _callWS (contr, Map data, Function callback, dynamic loading) {
        var cancel_loading = loadingRequest(loading);
        WebsocketService ws = new WebsocketService();
        ws.connect().then((_) {
            var ts = new WebsocketClient(contr, ws);
            ts.send(data).then((data) => cancel_loading(data, callback));
        });
    }

    _callAjax (contr, Map data, Function callback, dynamic loading, {timeout: 20000}) {
        var cancel_loading = loadingRequest(loading);
        var request = new HttpRequest();
        request.open('POST', path + contr, async:true);
        request.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
        request.timeout = timeout;
        request.onLoad.listen((e) {
            var data = JSON.decode(request.responseText);
            cancel_loading(data, callback);
        });
        request.onTimeout.listen((e) => cancel_loading());
        request.send(Uri.encodeFull('request='+JSON.encode(data)));
    }

}

class WebsocketClient {

    String action;

    WebsocketService srv;

    StreamController controller = new StreamController();

    WebsocketClient(this.action, this.srv);

    Future send([msg]) {
        Completer completer = new Completer();
        srv.scopes[srv.send(action, msg)] = this;
        controller.stream.listen(completer.complete);
        return completer.future;
    }

}

class WebsocketService {

    static WebsocketService instance;

    StreamController controller = new StreamController.broadcast();

    String _url;

    int requests;

    bool _connected = false;
    bool _connecting = false;

    WebSocket webSocket;

    Map<String, WebsocketClient> scopes = new Map();

    StreamController<bool> _conn = new StreamController.broadcast();

    factory WebsocketService([url]) {
        if(instance == null)
            instance = new WebsocketService._(url);
        return instance;
    }

    WebsocketService._(url) {
        _url = url;
    }

    Future connect() {
        Completer completer = new Completer();
        var subscr = _conn.stream.listen(null);
        subscr.onData((_) {
            subscr.cancel();
            completer.complete(true);
        });
        if(_connected)
            _conn.add(true);
        else if(!_connecting) {
            _connecting = true;
            requests = 0;
            webSocket = new WebSocket(_url);
            webSocket.onError.first.then((_) => onError());
            webSocket.onOpen.first.then((_) {
                webSocket.onMessage.listen((e) => onMessage(e.data));
                webSocket.onClose.first.then((_) => onClose());
                onConnect();
                _conn.add(true);
            });
        }
        return completer.future;
    }

    void onConnect() {
        _connected = true;
        _connecting = false;
    }

    void onClose() {
        _connected = false;
        _connecting = false;
    }

    void onError() {
        _connected = false;
        _connecting = false;
    }

    void onMessage(data) {
        var message = JSON.decode(data);
        var nmsp = scopes[message['nmsp']];
        if(nmsp != null) {
            nmsp.controller.add(message['rsp']);
            scopes.remove(message['nmsp']);
        } else {
            controller.add(message['rsp']);
        }
    }

    send(String controller, [String msg = '']) {
        if (webSocket != null && webSocket.readyState == WebSocket.OPEN) {
            var nmsp = (++requests).toString();
            webSocket.send(JSON.encode({'nmsp': nmsp, 'ctrl': controller, 'msg': msg}));
            return nmsp;
        } else
            new Timer(new Duration(seconds:1), () => send(controller, msg));
    }

}