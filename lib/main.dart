import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';

void main() {
  runApp(Main());
}

class Main extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSwatch(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        primaryColorDark: Colors.grey[900],
        accentColor: Colors.grey[300],
        cardColor: Color.fromARGB(255, 30, 30, 30),
        backgroundColor: Color.fromARGB(255, 15, 15, 15),
        errorColor: Colors.red[900],
      ),
    );
    return MaterialApp(
      title: 'SyncTube',
      theme: theme,
      home: ServerListPage(title: 'Latest Servers'),
    );
  }
}

class ServerListPage extends StatefulWidget {
  final String title;

  ServerListPage({Key? key, required this.title}) : super(key: key);

  @override
  _ServerListPageState createState() => _ServerListPageState();
}

class _ServerListPageState extends State<ServerListPage> {
  final List<ServerListItem> items = [];
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    readItems();
  }

  void readItems() async {
    final prefs = await SharedPreferences.getInstance();
    var strings = prefs.getStringList('serverListItems') ?? [];
    print(strings);
    if (strings.length == 0) {
      strings = ['Example', 'https://synctube-example.herokuapp.com'];
    }
    setState(() {
      for (var i = 0; i < strings.length; i += 2) {
        items.add(ServerListItem(strings[i], strings[i + 1]));
      }
    });
  }

  void writeItems() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> strings = [];
    for (var item in items) {
      strings.add(item.name);
      strings.add(item.url);
    }
    prefs.setStringList('serverListItems', strings);
  }

  void addItem(ServerListItem? item) {
    if (item == null) return;
    item.name = item.name.trim();
    item.url = item.url.trim();
    if (item.name.length == 0 || item.url.length == 0) return;
    setState(() => items.add(item));
    writeItems();
  }

  void editItem(ServerListItem item) async {
    await _serverItemDialog(context, item);
    setState(() {});
    writeItems();
  }

  void removeItem(ServerListItem item) {
    setState(() => items.remove(item));
    writeItems();
  }

  void itemPopupMenu(ServerListItem item) async {
    final overlay =
        Overlay.of(context)?.context.findRenderObject() as RenderBox;
    void Function()? func = await showMenu(
      context: context,
      position: RelativeRect.fromRect(
        (_tapPosition ?? Offset.zero) & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Copy Link'),
          value: () => Clipboard.setData(ClipboardData(text: item.url)),
        ),
        PopupMenuItem(
          child: const Text('Edit'),
          value: () => editItem(item),
        ),
        PopupMenuItem(
          child: const Text('Delete'),
          value: () => removeItem(item),
        ),
      ],
      elevation: 8.0,
    );
    if (func != null) func();
  }

  void openServer(ServerListItem item) {
    var link = item.url;
    if (!link.contains('://')) link = 'http://$link';
    final uri = Uri.parse(link);
    final protocol = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.port == 80 ? '' : ':${uri.port}';
    final url = '$protocol://${uri.host}$port${uri.path}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => App(
          name: item.name,
          url: url,
        ),
      ),
    );
  }

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    final listView = ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTapDown: _storePosition,
          child: ListTile(
            title: item.buildTitle(context),
            subtitle: item.buildSubtitle(context),
            onTap: () => openServer(item),
            onLongPress: () => itemPopupMenu(item),
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(child: listView),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          addItem(await _serverItemDialog(context));
        },
        tooltip: 'Add new server',
        child: Icon(Icons.add),
      ),
    );
  }
}

class ServerListItem {
  String name;
  String url;

  ServerListItem(this.name, this.url);

  Widget buildTitle(BuildContext context) => Text(name);

  Widget buildSubtitle(BuildContext context) => Text(url);
}

Future<ServerListItem?> _serverItemDialog(BuildContext context,
    [ServerListItem? item]) async {
  if (item == null) item = ServerListItem('', '');
  if (item.url.isEmpty) {
    final clipboard = await Clipboard.getData('text/plain');
    final clipboardText = clipboard?.text ?? '';
    if (clipboardText.contains('http')) {
      item.url = clipboardText;
      try {
        final host = Uri.parse(item.url).host;
        item.name = host.split('.')[0];
      } catch (e) {}
    }
  }
  return showDialog<ServerListItem>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        insetPadding: EdgeInsets.zero,
        scrollable: true,
        title: const Text('Add Server'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                textCapitalization: TextCapitalization.sentences,
                initialValue: item!.name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Server Name',
                  hintText: 'My Cool Server',
                ),
                onChanged: (value) => item!.name = value,
              ),
              TextFormField(
                initialValue: item.url,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'my-synctube.com',
                ),
                onChanged: (value) => item!.url = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Ok'),
            onPressed: () => Navigator.of(context).pop(item),
          ),
        ],
      );
    },
  );
}
