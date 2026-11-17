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

As grandezas macroscópicas saem das próprias partículas (gás 2D de esferas rígidas):

- **Temperatura**: energia cinética média das partículas (em 2D, `<½mv²> = kT`).
- **Pressão**: impulso entregue às paredes por unidade de tempo e de comprimento de parede, com média móvel de 1,5 s. Por isso o manômetro oscila um pouco.
- **Tampa**: move-se com velocidade finita e troca energia com as partículas que batem nela. Sem nada mantido constante, comprimir aquece e expandir esfria, e o trabalho mostrado é a soma dessas trocas (primeira lei).
- **Aquecedor**: atua no piso. Só as partículas que tocam o fundo ganham ou perdem energia, e o calor se espalha pelas colisões.
- **Velocidades**: sorteadas pela distribuição de Maxwell-Boltzmann. O histograma compara o medido com a curva teórica.

O painel de leituras mostra a pressão medida ao lado da previsão `PV = nRT`. A medida fica alguns por cento acima da ideal porque as partículas têm tamanho finito (o mesmo efeito do covolume de van der Waals), e a diferença cresce quando o gás é comprimido. Como o gás é 2D, a compressão adiabática segue `T·V = constante` (γ = 2), e não o `γ = 5/3` de um gás monoatômico 3D.

Os testes em `test/widget_test.dart` verificam conservação de energia, primeira lei, e as leis de Boyle e Charles (`flutter test`).


## Teste rápido no Windows

1. Extraia o ZIP.
2. Dê duplo clique em `CONFIGURAR_PROJETO.bat`.
3. Depois use `RODAR.bat` ou rode `flutter run`.

O script `CONFIGURAR_PROJETO.bat` executa `flutter create .` para gerar as pastas de plataforma que dependem da instalação local do Flutter.
