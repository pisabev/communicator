library communicator_carrier;

import 'dart:convert';

class Carrier {

    int namespace;

    String controller, message;

    static final _nmsp = 'n', _ctrl = 'c', _msg = 'm';

    dynamic data;

    Carrier([this.namespace = 0]);

    Carrier.atClient(data) {
        Map m = JSON.decode(data);
        namespace = m[_nmsp];
        message = m[_msg];
    }

    Carrier.atServer(data) {
        Map m = JSON.decode(data);
        namespace = m[_nmsp];
        controller = m[_ctrl];
        message = m[_msg];
    }

    toClient(message) => JSON.encode({_nmsp: namespace, _msg: message});

    toServer(controller, message) => JSON.encode({_nmsp: namespace, _ctrl: controller, _msg: message});

}