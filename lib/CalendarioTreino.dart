import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarioTreino extends StatefulWidget {
  @override
  _CalendarioTreinoState createState() => _CalendarioTreinoState();
}

class _CalendarioTreinoState extends State<CalendarioTreino> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Simulando um banco de dados de agendamentos
  // Chave: Data, Valor: Lista de Alunos/Horários
  Map<DateTime, List<String>> _agendamentos = {
    DateTime.utc(2023, 10, 25): ['08:00 - João Silva', '09:00 - Maria Souza'],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meu Expediente - Personal')),
      body: Column(
        children: [
          TableCalendar(
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
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildListaAlunos(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _exibirDialogoAgendamento(),
        child: Icon(Icons.add),
        tooltip: 'Adicionar Aluno',
      ),
    );
  }

  Widget _buildListaAlunos() {
    final alunos = _agendamentos[_selectedDay] ?? [];
    if (alunos.isEmpty) {
      return Center(child: Text("Nenhum aluno para este dia."));
    }
    return ListView.builder(
      itemCount: alunos.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: Icon(Icons.person, color: Colors.blue),
            title: Text(alunos[index]),
            trailing: Icon(Icons.notifications_active, size: 18),
          ),
        );
      },
    );
  }

  void _exibirDialogoAgendamento() {
    // Aqui você abriria um formulário para digitar o nome do aluno
    // e escolher o horário (TimePicker)
    print("Abrir tela de cadastro de treino");
  }
}