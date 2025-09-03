// main.dart
// Protótipo simples para registro e consulta de clientes e pedidos usando Dart e MySQL.
// Requisitos: Dart SDK, VS Code, MySQL Server, pacote mysql_client (adicionar ao pubspec.yaml: mysql_client: ^0.0.27 ou versão atual).
// Executar: dart pub get, depois dart run main.dart

import 'package:mysql_client/mysql_client.dart';
import 'dart:io';

// Classe Cliente
class Cliente {
  int? id;
  String nome;
  String email;

  Cliente({this.id, required this.nome, required this.email});

  // Método para inserir no banco (persistência)
  Future<void> inserir(MySQLConnection conn) async {
    final result = await conn.execute(
      "INSERT INTO clientes (nome, email) VALUES (:nome, :email)",
      {"nome": nome, "email": email},
    );
    id = result.lastInsertID.toInt();
    print("Cliente inserido com ID: $id");
  }

  // Método factory para criar a partir de mapa (para consultas)
  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int,
      nome: map['nome'] as String,
      email: map['email'] as String,
    );
  }
}

// Classe Pedido (relacionada 1:N com Cliente)
class Pedido {
  int? id;
  int clienteId;
  double valor;
  DateTime data;

  Pedido({this.id, required this.clienteId, required this.valor, required this.data});

  // Método para inserir no banco (persistência)
  Future<void> inserir(MySQLConnection conn) async {
    final result = await conn.execute(
      "INSERT INTO pedidos (cliente_id, valor, data) VALUES (:cliente_id, :valor, :data)",
      {
        "cliente_id": clienteId,
        "valor": valor,
        "data": data.toIso8601String().split('T')[0], // Formato YYYY-MM-DD
      },
    );
    id = result.lastInsertID.toInt();
    print("Pedido inserido com ID: $id");
  }

  // Método factory para criar a partir de mapa (para consultas)
  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] as int,
      clienteId: map['cliente_id'] as int,
      valor: map['valor'] as double,
      data: DateTime.parse(map['data'] as String),
    );
  }
}

// Função para estabelecer conexão com MySQL
Future<MySQLConnection> conectar() async {
  print("Conectando ao MySQL...");
  final conn = await MySQLConnection.createConnection(
    host: "127.0.0.1", // Ou localhost
    port: 3306,
    userName: "kauan", // Substitua pelo usuário do MySQL Workbench
    password: "senha", // Substitua pela senha do MySQL Workbench
    databaseName: "db_clientes_pedidos", // Nome do banco criado
    secure: false, // Use true se configurar SSL no MySQL
  );
  await conn.connect();
  print("Conectado!");
  return conn;
}

// Consulta 1: Listagem de pedidos com dados do cliente (JOIN)
Future<void> consultarPedidosComClientes(MySQLConnection conn) async {
  print("\n--- Listagem de Pedidos com Dados do Cliente ---");
  final results = await conn.execute(
    "SELECT p.id, p.cliente_id, p.valor, p.data, c.nome, c.email "
    "FROM pedidos p JOIN clientes c ON p.cliente_id = c.id",
  );

  if (results.rows.isEmpty) {
    print("Nenhum pedido encontrado.");
    return;
  }

  // Exibir formatado
  print("ID | Cliente ID | Valor | Data | Nome Cliente | Email");
  print("-----------------------------------------------------");
  for (final row in results.rows) {
    final map = row.assoc();
    print("${map['id']} | ${map['cliente_id']} | ${map['valor']} | ${map['data']} | ${map['nome']} | ${map['email']}");
  }
}

// Consulta 2: Resumo de pedidos por cliente com total gasto (GROUP BY)
Future<void> consultarResumoPorCliente(MySQLConnection conn) async {
  print("\n--- Resumo de Pedidos por Cliente (Total Gasto) ---");
  final results = await conn.execute(
    "SELECT c.id, c.nome, SUM(p.valor) AS total_gasto "
    "FROM clientes c JOIN pedidos p ON c.id = p.cliente_id "
    "GROUP BY c.id",
  );

  if (results.rows.isEmpty) {
    print("Nenhum resumo disponível.");
    return;
  }

  // Exibir formatado
  print("Cliente ID | Nome | Total Gasto");
  print("--------------------------------");
  for (final row in results.rows) {
    final map = row.assoc();
    print("${map['id']} | ${map['nome']} | ${map['total_gasto']}");
  }
}

// Função principal
Future<void> main() async {
  final conn = await conectar();

  // Exemplo de inclusão de cliente
  final cliente1 = Cliente(nome: "João Silva", email: "joao@example.com");
  await cliente1.inserir(conn);

  final cliente2 = Cliente(nome: "Maria Oliveira", email: "maria@example.com");
  await cliente2.inserir(conn);

  // Exemplo de inclusão de pedidos
  final pedido1 = Pedido(clienteId: cliente1.id!, valor: 150.50, data: DateTime.now());
  await pedido1.inserir(conn);

  final pedido2 = Pedido(clienteId: cliente1.id!, valor: 200.00, data: DateTime.now());
  await pedido2.inserir(conn);

  final pedido3 = Pedido(clienteId: cliente2.id!, valor: 300.75, data: DateTime.now());
  await pedido3.inserir(conn);

  // Executar consultas
  await consultarPedidosComClientes(conn);
  await consultarResumoPorCliente(conn);

  // Fechar conexão
  await conn.close();
  print("\nConexão fechada. Programa finalizado.");
}