enum SetStatus { libre, prep, record }

class SessionModel {
  int tema;
  int escena;
  SetStatus status;

  SessionModel({
    this.tema = 1,
    this.escena = 1,
    this.status = SetStatus.libre,
  });

  String get sceneLabel =>
      'Tema ${tema.toString().padLeft(2, '0')}, Escena ${escena.toString().padLeft(2, '0')}';
}
