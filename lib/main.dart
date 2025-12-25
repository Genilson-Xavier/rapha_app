import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart'; // O arquivo que criamos no passo anterior
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa notificações e fusos horários
  await NotificationService().init();

  // Inicializa tradução para PT-BR
  await initializeDateFormatting('pt_BR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CalendarioTreino(),
    );
  }
}

class CalendarioTreino extends StatefulWidget {
  const CalendarioTreino({super.key});

  @override
  State<CalendarioTreino> createState() => _CalendarioTreinoState();
}

class _CalendarioTreinoState extends State<CalendarioTreino> {
  final Map<int, String> _legendasCores = {
    Colors.blueAccent.value: "Hipertrofia",
    Colors.green.value: "Emagrecimento",
    Colors.orange.value: "Funcional / Cardio",
    Colors.purple.value: "Reabilitação",
  };
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Mapa de agendamentos usando um objeto para organizar melhor
  final Map<DateTime, List<Map<String, dynamic>>> _agendamentos = {};

  bool _permissaoConcedida = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _verificarPermissao();
    _carregarDados();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda do Rapha')),
      backgroundColor: const Color(0xFFF5F7FA), // Um cinza azulado muito claro e elegante
      body: Column(
        children: [
          TableCalendar(
            locale: 'pt_BR',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },

            // --- ESTILIZAÇÃO PROFISSIONAL ---
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(12.0),
              ),
              formatButtonTextStyle: const TextStyle(color: Colors.white),
              titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.orangeAccent,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false, // Esconde dias do mês anterior/próximo para limpar o visual
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
              weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ),
          _buildResumoDoDia(),
          const Divider(),
          Expanded(child: _buildListaAlunos()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exibirDialogoAgendamento(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildListaAlunos() {
    final dataChave = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final lista = _agendamentos[dataChave] ?? [];

    if (lista.isEmpty) return const Center(child: Text("Nenhum treino agendado."));

    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final treino = lista[index];
        bool isConcluido = treino['concluido'] ?? false;
        // Verifique se você usou 'notas' ou 'notes' no seu código e ajuste abaixo:
        String notaTexto = treino['notas'] ?? treino['notes'] ?? "";
        int corDoTreino = treino['cor'] ?? Colors.blueAccent.value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isConcluido ? Colors.green.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Garante que a barra lateral preencha a altura
              children: [
                // Barra lateral
                Tooltip(
                  message: _legendasCores[corDoTreino] ?? "Treino",
                  waitDuration: Duration.zero, // Aparece imediatamente ao segurar
                  showDuration: const Duration(seconds: 2), // Fica visível por 2 segundos
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: isConcluido ? Colors.green : Color(corDoTreino),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Conteúdo do Card
                Expanded( // O Expanded aqui é fundamental para o texto não "fugir" para a direita
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Ícone de Check-in
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact(); // Pequena vibração no dedo
                                setState(() => treino['concluido'] = !isConcluido);
                                _salvarDados();
                              },
                              child: Icon(
                                isConcluido ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: isConcluido ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Nome e Hora
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${treino['aluno']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      decoration: isConcluido ? TextDecoration.lineThrough : null,
                                      color: isConcluido ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    "Horário: ${treino['hora']}",
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            // Botão Deletar
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _confirmarExclusao(dataChave, index),
                            ),
                          ],
                        ),

                        // Bloco de Notas (Agora com tratamento de quebra de linha)
                        if (notaTexto.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 40, top: 8, right: 8),
                            child: Container(
                              width: double.infinity, // Força o container a respeitar a largura do pai
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Obs: $notaTexto",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: isConcluido ? Colors.grey : Colors.blueGrey.shade800,
                                ),
                                softWrap: true, // Permite quebra de linha
                                overflow: TextOverflow.visible, // Garante que o texto apareça
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exibirDialogoAgendamento() async {
    final TextEditingController _nomeController = TextEditingController();
    final TextEditingController _antecedenciaController = TextEditingController(text: "15");
    final TextEditingController _notasController = TextEditingController();
    int corSelecionada = Colors.blueAccent.value; // Padrão: Azul
    TimeOfDay? horaSelecionada = TimeOfDay.now();
    List<int> diasSelecionados = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agendamento Semanal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeController,
                  decoration: const InputDecoration(labelText: "Nome do Aluno", prefixIcon: Icon(Icons.person)),
                ),
                TextField(
                  controller: _notasController,
                  decoration: const InputDecoration(
                    labelText: "Observações/Treino do dia",
                    prefixIcon: Icon(Icons.note_alt_outlined),
                    hintText: "Ex: Focar em pernas...",
                  ),
                  maxLines: 2,
                ), // Fechamento correto do TextField
                const SizedBox(height: 15),
                const Text("Dias da semana:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  children: List.generate(7, (index) {
                    final nomesDias = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
                    final valorDia = index == 0 ? 7 : index;
                    final isSelected = diasSelecionados.contains(valorDia);
                    return ChoiceChip(
                      label: Text(nomesDias[index]),
                      selected: isSelected,
                      onSelected: (val) {
                        setDialogState(() {
                          val ? diasSelecionados.add(valorDia) : diasSelecionados.remove(valorDia);
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 15),
                const Text("Objetivo do Treino:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildColorOption(setDialogState, Colors.blueAccent.value, corSelecionada, (val) => corSelecionada = val),
                    _buildColorOption(setDialogState, Colors.green.value, corSelecionada, (val) => corSelecionada = val),
                    _buildColorOption(setDialogState, Colors.orange.value, corSelecionada, (val) => corSelecionada = val),
                    _buildColorOption(setDialogState, Colors.purple.value, corSelecionada, (val) => corSelecionada = val),
                  ],
                ),
                const SizedBox(height: 15),
                ListTile(
                  title: Text("Horário: ${horaSelecionada?.format(context)}"),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: horaSelecionada!);
                    if (picked != null) setDialogState(() => horaSelecionada = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => _processarAgendamentoSemanal(
                _nomeController.text,
                horaSelecionada!,
                diasSelecionados,
                int.tryParse(_antecedenciaController.text) ?? 15,
                _notasController.text, // Agora o código vai reconhecer este 5º argumento
                corSelecionada,
              ),
              child: const Text('Confirmar Semana'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verificarPermissao() async {
    final status = await Permission.notification.status;
    setState(() {
      _permissaoConcedida = status.isGranted;
    });
  }

  Future<void> _pedirPermissao() async {
    final status = await Permission.notification.request();
    setState(() {
      _permissaoConcedida = status.isGranted;
    });
  }

  // 1. Chame isso no initState para carregar os dados ao abrir o app
  Future<void> _carregarDados() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dadosSalvos = prefs.getString('agenda_personal');

    if (dadosSalvos != null) {
      setState(() {
        Map<String, dynamic> decoded = jsonDecode(dadosSalvos);
        // Converte o texto de volta para o formato de data e lista
        decoded.forEach((key, value) {
          _agendamentos[DateTime.parse(key)] = List<Map<String, dynamic>>.from(value);
        });
      });
    }
  }

// 2. Chame isso toda vez que adicionar um aluno novo
  Future<void> _salvarDados() async {
    final prefs = await SharedPreferences.getInstance();
    // Transformamos as chaves DateTime em String para o JSON aceitar
    Map<String, String> dataParaSalvar = {};
    final mapaString = _agendamentos.map((key, value) =>
        MapEntry(key.toIso8601String(), value));

    await prefs.setString('agenda_personal', jsonEncode(mapaString));
  }

  void _confirmarExclusao(DateTime dataChave, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Desmarcar Aluno?"),
        content: const Text("Tem certeza que deseja remover este agendamento?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _agendamentos[dataChave]!.removeAt(index);
                // Se o dia ficou vazio, removemos a chave do mapa para economizar memória
                if (_agendamentos[dataChave]!.isEmpty) {
                  _agendamentos.remove(dataChave);
                }
              });
              _salvarDados(); // Atualiza o SharedPreferences
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Agendamento removido!")),
              );
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoDoDia() {
    final dataChave = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final totalAlunos = _agendamentos[dataChave]?.length ?? 0;
    final dataFormatada = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_selectedDay!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.blue.withOpacity(0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dataFormatada.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalAlunos == 0
                    ? "Nenhum aluno agendado"
                    : "$totalAlunos Aluno${totalAlunos > 1 ? 's' : ''} para hoje",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _copiarAgendaSemanaPassada,
                icon: const Icon(Icons.copy_all, size: 20),
                label: const Text("Copiar Anterior"),
                style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
              ),
              Icon(
                totalAlunos == 0 ? Icons.event_available : Icons.fitness_center,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _processarAgendamentoSemanal(String nome, TimeOfDay hora, List<int> dias, int alerta, String notas, int cor) async {
    if (nome.isEmpty || dias.isEmpty) return;

    DateTime referencia = _selectedDay ?? DateTime.now();
    DateTime segundaFeiraDaSemana;

    // AJUSTE PARA O SEU FLUXO DE DOMINGO:
    // Se você clicou no Domingo (7), queremos a segunda-feira que VEM (amanhã).
    // Se clicou em qualquer outro dia, pegamos a segunda desta semana.
    if (referencia.weekday == DateTime.sunday) {
      segundaFeiraDaSemana = referencia.add(const Duration(days: 1));
    } else {
      segundaFeiraDaSemana = referencia.subtract(Duration(days: referencia.weekday - 1));
    }

    for (int diaSemana in dias) {
      // 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex, 6=Sab, 7=Dom
      // Calculamos a data baseada na segunda-feira que definimos acima
      DateTime dataAlvo = segundaFeiraDaSemana.add(Duration(days: diaSemana - 1));

      DateTime dataCompleta = DateTime(
          dataAlvo.year, dataAlvo.month, dataAlvo.day,
          hora.hour, hora.minute
      );

      final dataChave = DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);

      setState(() {
        final novoTreino = {
          'aluno': nome,
          'hora': hora.format(context),
          'antecedencia': alerta,
          'notas': notas,
          'concluido': false,
          'cor': cor,
        };
        _agendamentos.putIfAbsent(dataChave, () => []).add(novoTreino);
      });

      if (dataCompleta.isAfter(DateTime.now())) {
        await NotificationService().agendarNotificacao(
          id: dataCompleta.millisecondsSinceEpoch ~/ 1000,
          titulo: "Treino com $nome",
          corpo: "Horário: ${hora.format(context)}",
          horario: dataCompleta,
          minutosAntes: alerta,
        );
      }
    }

    _salvarDados();
    Navigator.pop(context);
  }

  void _copiarAgendaSemanaPassada() async {
    DateTime referencia = _selectedDay ?? DateTime.now();

    // 1. Descobrir a Segunda-Feira da semana selecionada (Alvo)
    DateTime segundaDestaSemana;
    if (referencia.weekday == DateTime.sunday) {
      segundaDestaSemana = referencia.add(const Duration(days: 1));
    } else {
      segundaDestaSemana = referencia.subtract(Duration(days: referencia.weekday - 1));
    }

    // 2. A "Semana Passada" são exatamente os 7 dias ANTES dessa segunda-feira
    DateTime segundaSemanaPassada = segundaDestaSemana.subtract(const Duration(days: 7));

    bool houveCopia = false;

    setState(() {
      for (int i = 0; i < 7; i++) {
        DateTime diaOrigem = segundaSemanaPassada.add(Duration(days: i));
        DateTime diaDestino = segundaDestaSemana.add(Duration(days: i));

        // Normaliza as datas para garantir que a comparação no Mapa funcione
        DateTime chaveOrigem = DateTime(diaOrigem.year, diaOrigem.month, diaOrigem.day);
        DateTime chaveDestino = DateTime(diaDestino.year, diaDestino.month, diaDestino.day);

        final treinosPassados = _agendamentos[chaveOrigem];

        if (treinosPassados != null && treinosPassados.isNotEmpty) {
          _agendamentos[chaveDestino] = List<Map<String, dynamic>>.from(
              treinosPassados.map((t) {
                var novoT = Map<String, dynamic>.from(t);
                novoT['concluido'] = false; // Garante que a nova semana comece limpa
                return novoT;
              })
          );
          houveCopia = true;
        }
      }
    });

    if (houveCopia) {
      _salvarDados();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Agenda copiada da semana anterior!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não encontrei treinos na semana anterior.")),
      );
    }
  }

// Função auxiliar para agendar os alertas dos treinos copiados
  void _agendarNotificacoesDaSemanaCopiada(DateTime data, List<Map<String, dynamic>> treinos) {
    for (var treino in treinos) {
      // Converte a string de hora de volta para DateTime para agendar o alerta
      // Nota: Requer um pequeno ajuste se você quiser notificações exatas na cópia
    }
  }

  Widget _buildColorOption(StateSetter setState, int colorValue, int currentSelected, Function(int) onSelect) {
    bool isSelected = colorValue == currentSelected;
    // Busca o nome da categoria no mapa que criamos acima
    String mensagem = _legendasCores[colorValue] ?? "Categoria";

    return Tooltip(
      message: mensagem, // Texto que aparecerá ao passar o mouse
      child: GestureDetector(
        onTap: () => setState(() => onSelect(colorValue)),
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: Color(colorValue),
            shape: BoxShape.circle,
            border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
          ),
          child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
        ),
      ),
    );
  }
}