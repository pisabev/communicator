library communicator_carrier;

import 'dart:convert';

class Carrier {

    int namespace;

    String controller, message;

    static final _nmsp = 'n', _ctrl = 'c', _msg = 'm';

    dynamic data;

    Carrier(this.controller, [this.namespace = 0]);

    Carrier.fromData(data) {
        Map m = JSON.decode(data);
        namespace = m[_nmsp];
        controller = m[_ctrl];
        message = m[_msg];
    }

    formMessage(message) => JSON.encode({_nmsp: namespace, _ctrl: controller, _msg: message});

}