// Copyright 2017, Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:throttling/throttling.dart';

import './widgets.dart';

class LightService {
  static const UUID = 'e0992b8e-3deb-4644-8901-a8241064bfb9';
  static const SEND_LIGHT_STATUS = '6a00e857-2e06-43ab-bb43-618a156e572a';
  static const RECIEVE_LIGHT_STATUS = 'c10cfc4b-5605-4db2-be14-bdd67ede7f26';

  static const LIGHT_STAGE_ON = [0x01];
  static const LIGHT_STAGE_OFF = [0x00];
}

class ControlService {
  static const UUID = 'eebb9f2e-e0b4-40e6-8269-4524d07b972c';
  static const SEND_STEARING_ANGLE = '21909a07-0fbf-42fd-b329-d6e29d33a2c6';
  static const RECIVE_STEARING_ANGLE = '8d584813-7e56-48ab-92fc-f38c54d391e7';
}

void main() {
  runApp(FlutterBlueApp());
}

List<int> intToMessage(int value) {
  int byte1 = value & 0xff;
  int byte2 = (value >> 8) & 0xff;
  return [byte1, byte2];
}

class FlutterBlueApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.lightBlue,
      home: StreamBuilder<BluetoothState>(
          stream: FlutterBlue.instance.state,
          initialData: BluetoothState.unknown,
          builder: (c, snapshot) {
            final state = snapshot.data;
            if (state == BluetoothState.on) {
              return FindDevicesScreen();
            }
            return BluetoothOffScreen(state: state);
          }),
    );
  }
}

class BluetoothOffScreen extends StatelessWidget {
  const BluetoothOffScreen({Key? key, this.state}) : super(key: key);

  final BluetoothState? state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.bluetooth_disabled,
              size: 200.0,
              color: Colors.white54,
            ),
            Text(
              'Bluetooth Adapter is ${state != null ? state.toString().substring(15) : 'not available'}.',
              style: Theme.of(context)
                  .primaryTextTheme
                  .subhead
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class FindDevicesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Devices'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            FlutterBlue.instance.startScan(timeout: Duration(seconds: 4)),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              StreamBuilder<List<BluetoothDevice>>(
                stream: Stream.periodic(Duration(seconds: 2))
                    .asyncMap((_) => FlutterBlue.instance.connectedDevices),
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map((d) => ListTile(
                            title: Text(d.name),
                            subtitle: Text(d.id.toString()),
                            trailing: StreamBuilder<BluetoothDeviceState>(
                              stream: d.state,
                              initialData: BluetoothDeviceState.disconnected,
                              builder: (c, snapshot) {
                                if (snapshot.data ==
                                    BluetoothDeviceState.connected) {
                                  return RaisedButton(
                                    child: Text('OPEN'),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                DeviceScreen(device: d))),
                                  );
                                }
                                return Text(snapshot.data.toString());
                              },
                            ),
                          ))
                      .toList(),
                ),
              ),
              StreamBuilder<List<ScanResult>>(
                stream: FlutterBlue.instance.scanResults,
                initialData: [],
                builder: (c, snapshot) => Column(
                  children: snapshot.data!
                      .map(
                        (r) => ScanResultTile(
                          result: r,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            r.device.connect();
                            return DeviceScreen(device: r.device);
                          })),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: StreamBuilder<bool>(
        stream: FlutterBlue.instance.isScanning,
        initialData: false,
        builder: (c, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              child: Icon(Icons.stop),
              onPressed: () => FlutterBlue.instance.stopScan(),
              backgroundColor: Colors.red,
            );
          } else {
            return FloatingActionButton(
                child: Icon(Icons.search),
                onPressed: () => FlutterBlue.instance
                    .startScan(timeout: Duration(seconds: 4)));
          }
        },
      ),
    );
  }
}

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key, required this.device}) : super(key: key);

  final BluetoothDevice device;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  double _currentSliderValue = 20;

  var deb = Debouncing(duration: const Duration(microseconds: 200));

  void sendThrottle(BluetoothCharacteristic characteristic, int angle) {
    characteristic.write(intToMessage(angle), withoutResponse: true);
  }

  Widget _buildServiceTiles(Map<String, BluetoothService> services) {
    List<Widget> serviceControls = [];
    if (services[LightService.UUID] != null) {
      serviceControls.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
              onPressed: () => {
                    services[LightService.UUID]!
                        .characteristics
                        .firstWhere((element) =>
                            element.uuid.toString() ==
                            LightService.RECIEVE_LIGHT_STATUS)
                        .write(LightService.LIGHT_STAGE_ON)
                  },
              child: Text("Light On")),
          Padding(padding: EdgeInsets.only(left: 20)),
          ElevatedButton(
              onPressed: () => {
                    services[LightService.UUID]!
                        .characteristics
                        .firstWhere((element) =>
                            element.uuid.toString() ==
                            LightService.RECIEVE_LIGHT_STATUS)
                        .write(LightService.LIGHT_STAGE_OFF)
                  },
              child: Text("Light Off"))
        ],
      ));
    }
    if (services[ControlService.UUID] != null) {
      serviceControls.add(Slider(
        value: _currentSliderValue,
        min: 0,
        max: 180,
        divisions: 180,
        label: _currentSliderValue.round().toString(),
        onChanged: (double value) {
          if (value != _currentSliderValue) {
            deb.debounce(() {
              sendThrottle(
                  services[ControlService.UUID]!.characteristics.firstWhere(
                      (element) =>
                          element.uuid.toString() ==
                          ControlService.RECIVE_STEARING_ANGLE),
                  value.toInt());
            });
            setState(() {
              _currentSliderValue = value;
            });
          }
        },
      ));
    }

    return Column(
      children: serviceControls,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: <Widget>[
          StreamBuilder<BluetoothDeviceState>(
            stream: widget.device.state,
            initialData: BluetoothDeviceState.connecting,
            builder: (c, snapshot) {
              VoidCallback? onPressed;
              String text;
              switch (snapshot.data) {
                case BluetoothDeviceState.connected:
                  onPressed = () => widget.device.disconnect();
                  text = 'DISCONNECT';
                  break;
                case BluetoothDeviceState.disconnected:
                  onPressed = () => widget.device.connect();
                  text = 'CONNECT';
                  break;
                default:
                  onPressed = null;
                  text = snapshot.data.toString().substring(21).toUpperCase();
                  break;
              }
              return TextButton(
                  onPressed: onPressed,
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .primaryTextTheme
                        .button
                        ?.copyWith(color: Colors.white),
                  ));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            StreamBuilder<BluetoothDeviceState>(
              stream: widget.device.state,
              initialData: BluetoothDeviceState.connecting,
              builder: (c, snapshot) => ListTile(
                leading: (snapshot.data == BluetoothDeviceState.connected)
                    ? Icon(Icons.bluetooth_connected)
                    : Icon(Icons.bluetooth_disabled),
                title: Text(
                    'Device is ${snapshot.data.toString().split('.')[1]}.'),
                subtitle: Text('${widget.device.id}'),
                trailing: StreamBuilder<bool>(
                  stream: widget.device.isDiscoveringServices,
                  initialData: false,
                  builder: (c, snapshot) => IndexedStack(
                    index: snapshot.data! ? 1 : 0,
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: () => {
                          widget.device.discoverServices(),
                        },
                      ),
                      IconButton(
                        icon: SizedBox(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Colors.grey),
                          ),
                          width: 18.0,
                          height: 18.0,
                        ),
                        onPressed: null,
                      )
                    ],
                  ),
                ),
              ),
            ),
            StreamBuilder<List<BluetoothService>>(
              stream: widget.device.services,
              initialData: [],
              builder: (c, snapshot) {
                Map<String, BluetoothService> services = Map.fromIterable(
                    snapshot.data!,
                    key: (e) => e.uuid.toString(),
                    value: (e) => e);
                return _buildServiceTiles(services);
              },
            ),
          ],
        ),
      ),
    );
  }
}
