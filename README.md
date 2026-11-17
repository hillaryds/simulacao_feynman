# PhysGame Gas Lab

Protótipo Flutter de um laboratório virtual de propriedades dos gases, redesenhado para o PhysGame.

## O que foi implementado

- Câmara com pistão arrastável.
- Partículas leves e pesadas.
- Movimento e colisões partícula-parede.
- Colisões partícula-partícula com massas diferentes.
- Temperatura alterando a velocidade das partículas.
- Controle de volume, temperatura e gravidade.
- Adição e remoção de partículas.
- Modos de variável constante: nenhuma, volume, temperatura e pressão.
- Manômetro.
- Pressão em kPa e conversão para mmHg.
- Taxa de colisões com paredes.
- Trabalho P·V acumulado.
- Histograma visual de velocidades.
- Experimento de difusão com divisória.
- Histórico de pressão.
- Missão guiada com validação e XP.
- Layout responsivo.

## Executar

Na pasta do projeto:

```bash
flutter pub get
flutter run
```

Escolha Windows, Chrome, Edge ou um emulador Android.

Este projeto NÃO usa WebView e não depende de `webview_flutter`.

## Organização

- `lib/simulation/`: motor e entidades da simulação.
- `lib/widgets/`: visualização da câmara, manômetro e gráficos.
- `lib/screens/`: tela principal.
- `lib/core/`: tema e identidade visual.

## Observação científica

A pressão macroscópica é calculada com `PV = nRT`. O motor de partículas fornece a representação microscópica e a taxa de colisões. A calibração absoluta da pressão não é obtida diretamente do impulso das partículas 2D deste protótipo.


## Teste rápido no Windows

1. Extraia o ZIP.
2. Dê duplo clique em `CONFIGURAR_PROJETO.bat`.
3. Depois use `RODAR.bat` ou rode `flutter run`.

O script `CONFIGURAR_PROJETO.bat` executa `flutter create .` para gerar as pastas de plataforma que dependem da instalação local do Flutter.
