# FS25_EnhancedVehicle

**Direkter Download / direct download: [FS25_EnhancedVehicle.zip](https://github.com/ZhooL/FS25_EnhancedVehicle/releases/latest/download/FS25_EnhancedVehicle.zip)**

[Jump to english documentation](#english)

Dies ist eine Modifikation für den Landwirtschafts-Simulator 25. Sie fügt dem Fahrzeug einen „Spurassistenten“ („GPS“) und eine Funktion zum Einrasten in die Fahrtrichtung hinzu, sowie eine Feststellbremse, Differenzialsperren, Radantriebsmodi und verbesserte Hydrauliksteuerungen. Außerdem werden mehr Fahrzeugdetails und ein Kilometerzähler auf dem HUD angezeigt.

**Hinweis: Die einzigen validen Downloadquellen sind meine Homepage (https://www.majo76.de) und dieses Github Repository (https://github.com/ZhooL/FS25_EnhancedVehicle). Alle anderen Downloadadressen sind nicht von mir validiert - also mit Vorsicht zu genießen.**

*(c) 2018-2025 Majo76 (vormals ZhooL). Sei so nett und erwähne mich, wenn du diesen Mod oder den Quellcode (oder Teile davon) irgendwo verwendest. Es ist untersagt, dieses Mod zu monetarisieren.*
Lizenz: https://creativecommons.org/licenses/by-nc-sa/4.0/

## Bekannte Probleme
* Möglicherweise einige... bitte via Github issues melden

## Das HUD erklärt
![HUD overview](/misc/hud_overview_de.png)

## Standard Tastenbelegung
| Taste | Aktion |
| --  | --     |
| <kbd>R Strg</kbd>+<kbd>Num /</kbd> | öffnet das Konfigurationsmenü um diverse EV-Einstellungen vornehmen zu können |
| <kbd>Num Enter</kbd> | Feststellbreme aktivieren/lösen |
| <kbd>R Strg</kbd>+<kbd>Ende</kbd> | in aktuelle Fahrtrichtung oder Fahrspur einrasten |
| <kbd>R Strg</kbd>+<kbd>Pos1</kbd> | aktuelle Fahrtrichtung oder Fahrspur umkehren (um 180°) (= umdrehen) |
| <kbd>R Shift</kbd>+<kbd>Pos1</kbd> | Betriebsmodus wechseln (Fahrtrichtung halten oder Fahrspur halten)<br/>Drücken und halten um Assistent zu deaktivieren |
| <kbd>R Strg</kbd>+<kbd>Num 1</kbd> | Arbeitsbreite neu berechnen (z.B. wenn Ausbringbreite sich geändert hat) |
| <kbd>R Strg</kbd>+<kbd>Num 2</kbd> | Fahrspurlayout neu berechnen (z.B. wenn Fahrtrichtung oder Arbeitsbreite sich geändert haben) |
| <kbd>R Strg</kbd>+<kbd>Num 3</kbd> | Durch verschiedene Anzeigemodi für die Hilfslinien wechseln |
| <kbd>R Strg</kbd>+<kbd>Num 4</kbd> / <kbd>Num 6</kbd> | Anzahl der zu überspringenden Fahrspuren beim Wenden verringern/erhöhen |
| <kbd>R Strg</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | Fahrspurlayout nach links/rechts verschieben |
| <kbd>R Strg</kbd>+<kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | Offsetlinie innerhalb einer Fahrspur nach links/rechts verschieben |
| <kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | Fahrspurbreite verringern/erhöhen |
| <kbd>R Strg</kbd>+<kbd>Einfg</kbd> / <kbd>Entf</kbd> | Fahrzeug eine Fahrspur nach rechts/links bewegen (ohne zu wenden) |
| <kbd>R Strg</kbd>+<kbd>Bild-hoch</kbd> / <kbd>Bild-runter</kbd> | Fahrzeug/Spurausrichtung um 1° erhöhen/verringern |
| <kbd>R Shift</kbd>+<kbd>Bild-hoch</kbd> / <kbd>Bild-runter</kbd> | Fahrzeug/Spurausrichtung um 45° erhöhen/verringern |
| <kbd>R Strg</kbd>+<kbd>R Shift</kbd>+<kbd>Bild-hoch</kbd> / <kbd>Bild-runter</kbd> | Fahrzeug/Spurausrichtung um 0,25° erhöhen/verringern |
| <kbd>R Strg</kbd>+<kbd>Num *</kbd> | Durch verschiedene Modi für automatisierte Aktionen am Feldende wechseln |
| <kbd>R Shift</kbd>+<kbd>Num /</kbd> / <kbd>Num *</kbd> | Durch verschiedene Abstände zum Feldende wechseln |
| <kbd>R Strg</kbd>+<kbd>Num 5</kbd> | Zwischen Gesamtkilometeranzeige oder "Tageskilometerzähler" wechseln.<br/>Drücken und halten, um Tageskilometer auf 0 zu setzen |
| <kbd>R Strg</kbd>+<kbd>Num 7</kbd> | Differential der Vorderachse sperren/entsperren |
| <kbd>R Strg</kbd>+<kbd>Num 8</kbd> | Differential der Hinterachse sperren/entsperren |
| <kbd>R Strg</kbd>+<kbd>Num 9</kbd> | Antriebsmodus wechseln zwischen 2-Rad-Antrieb oder Allrad |
| <kbd>L Alt</kbd>+<kbd>1</kbd> | alle hinten angehängten Geräte hoch/runter |
| <kbd>L Alt</kbd>+<kbd>2</kbd> | alle hinten angehängten Geräte an/aus |
| <kbd>L Alt</kbd>+<kbd>3</kbd> | alle vorne angehängten Geräte hoch/runter |
| <kbd>L Alt</kbd>+<kbd>4</kbd> | alle vorne angehängten Geräte an/aus |
| <kbd>L Alt</kbd>+<kbd>5</kbd> | alle hinten angehängten Geräte aus/einklappen |
| <kbd>L Alt</kbd>+<kbd>6</kbd> | alle vorne angehängten Geräte aus/einklappen |

## Was dieses Mod macht
* Wenn das Spiel startet, werden alle „motorisierten“ und „steuerbaren“ Fahrzeuge auf der Karte auf die Standardeinstellungen umgestellt: Allradantrieb und Deaktivierung beider Differentiale.
* Drücke <kbd>Strg</kbd>+<kbd>Numpad /</kbd> um das Konfigurationsmenü zu öffnen.
* Drücke <kbd>R Shift</kbd>+<kbd>Pos1</kbd> um die Fahrtrichtung zu halten oder den Spurassistenten zu aktivieren.
  * Drücke und halte <kbd>R Shift</kbd>+<kbd>Pos1</kbd> für mindestens eine Sekunde um das Einrasten der Fahrtrichtung und den Spurassistenten komplett zu deaktivieren.
* Drücke <kbd>R Strg</kbd>+<kbd>Ende</kbd> um dein Fahrzeug in die aktuelle Richtung oder die aktuelle Spur einzurasten.
  * Drücke <kbd>R Strg</kbd>+<kbd>Pos1</kbd> um die Fahrtrichtung (auch in einer Fahrspur) um 180° zu drehen (z.B. um am Feldende zu wenden).
* Drücke <kbd>R Strg</kbd>+<kbd>Numpad 2</kbd> um das Fahrspurenlayout basierend auf der aktuellen Fahrtrichtung des Fahrzeugs und den angehängten Geräten (neu) zu berechnen.
  * Wenn du jetzt in die Fahrspur einrastet, wird das Fahrzeug in die markierte Spur einfahren und bleiben.
  * Drücke <kbd>R Strg</kbd>+<kbd>Numpad 4/6</kbd> um die Anzahl der zu überspringeden Fahrspuren beim Wenden einzustellen (von -5 bis 5).
  * Automatisierte Aktionen am Feldende können im Konfigurationsmenü oder per Tasten eingestellt werden.
* Drücke <kbd>R Strg</kbd>+<kbd>Numpad 1</kbd> um die Arbeitsbreite (neu) zu berechnen. Dies ändert nicht das Fahrspurlayout.
* Drücke <kbd>Numpad Enter</kbd> um das Fahrzeug per Feststellbremse zu blockieren/zu lösen. Es wird sich keinen Zentimeter mehr bewegen.
* Im HUD wird angezeigt:
  * (Wenn Fahrspurhalten/-assistent is aktiv) Die aktuelle Wunsch-Fahrtrichtung in Grad, sowie die aktuelle Fahrspur und Anzahl der zu überspringenden Fahrspuren beim Wenden.
  * Schaden des aktuellen Fahrzeugs und aller verbundenen Geräte in %.
  * Füllstand für Diesel/AdBlue/Elektrisch/Methan und die aktuelle Verbrauchsrate<sup>1</sup>.
  * Die Gesamtkilometer Laufleistung des Fahrzeugs oder der "Tageskilometerzähler".
  * Der aktuelle Stand der Differentialsperren und des Antriebsmodus.
  * Die Motordrehzahl und -temperatur<sup>1</sup>.
  * Das aktuelle Gewicht des Fahrzeugs und die Gesamtmasse mit allen verbundenen Geräten und deren Fracht.
* Tastaturbelegung kann im Einstellungsmenü des Spiels angepasst werden.

**<sup>1</sup> In Multiplayer-Spielen zeigen alle Clients, außer dem Host, den Treibstoffverbrauch und die Motortemperatur aufgrund von GIANTS-Engine-Einschränkungen nicht korrekt an**

## Was dieses Mod nicht (vollständig) macht
* Auf Konsolen laufen. Kauf 'nen PC für vernünftiges Zocken.

# English

This is a modification for Farming Simulator 25. It adds a "track assistant" ("GPS") and a "snap to driving direction" feature, a parking brake, differential locks, wheel drive modes and improved hydraulics controls to your vehicle. It also shows more vehicle details on the HUD including a odo/tripmeter.

**Note: The only valid download sources are my homepage (https://www.majo76.de) and this Github repository (https://github.com/ZhooL/FS25_EnhancedVehicle). All other download addresses are not validated by me - so please use with caution.

*(c) 2018-2025 by Majo76 (formerly ZhooL). Be so kind to credit me when using this mod or the source code (or parts of it) somewhere. Monetization of this mod is prohibited.*
License: https://creativecommons.org/licenses/by-nc-sa/4.0/

## Known bugs
* Probably a lot... please report them via Github issues

## The HUD explained
![HUD overview](/misc/hud_overview_en.png)

## Default Keybindings
| Key | Action |
| --  | --     |
| <kbd>R Ctrl</kbd>+<kbd>Num /</kbd> | opens the config dialog to adjust various settings |
| <kbd>Num Enter</kbd> | apply/release parking brake |
| <kbd>R Ctrl</kbd>+<kbd>End</kbd> | snap to current driving direction or current track |
| <kbd>R Ctrl</kbd>+<kbd>Home</kbd> | reverse snap/track direction (180°) (= turn around) |
| <kbd>R Shift</kbd>+<kbd>Home</kbd> | change operational mode (snap to direction or snap to track)<br/>press & hold for one second to disable snap assistant |
| <kbd>R Ctrl</kbd>+<kbd>Num 1</kbd> | re-calculate working width (e.g. spraying width changed) |
| <kbd>R Ctrl</kbd>+<kbd>Num 2</kbd> | re-calculate track layout (e.g. direction changed or working width changed) |
| <kbd>R Ctrl</kbd>+<kbd>Num 3</kbd> | cycle through the different show lines modes |
| <kbd>R Ctrl</kbd>+<kbd>Num 4</kbd> / <kbd>Num 6</kbd> | decrease/increase the number of turnover tracks |
| <kbd>R Ctrl</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | move track layout to the left/right |
| <kbd>R Ctrl</kbd>+<kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | move track offset line to the left/right |
| <kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | decrease/increase track width |
| <kbd>R Ctrl</kbd>+<kbd>Insert</kbd> / <kbd>Delete</kbd> | move vehicle one track to the right/left without turning around |
| <kbd>R Ctrl</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | increase/decrease snap/track direction by 1° |
| <kbd>R Shift</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | increase/decrease snap/track direction by 45° |
| <kbd>R Ctrl</kbd>+<kbd>R Shift</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | increase/decrease snap/track direction by 0.25° |
| <kbd>R Ctrl</kbd>+<kbd>Num *</kbd> | cycle through the different headland modes |
| <kbd>R Shift</kbd>+<kbd>Num /</kbd> / <kbd>Num *</kbd> | cycle through headland distances |
| <kbd>R Ctrl</kbd>+<kbd>Num 5</kbd> | Switch between overall kilometer counter or trip kilometer counter.<br/>Press and hold to reset trip kilometer counter to 0|
| <kbd>R Ctrl</kbd>+<kbd>Num 7</kbd> | enable/disable front axle differential lock |
| <kbd>R Ctrl</kbd>+<kbd>Num 8</kbd> | enable/disable back axle differential lock |
| <kbd>R Ctrl</kbd>+<kbd>Num 9</kbd> | switch wheel drive mode between 4WD (four wheel drive) or 2WD (two wheel drive) |
| <kbd>L Alt</kbd>+<kbd>1</kbd> | all rear attached devices up/down |
| <kbd>L Alt</kbd>+<kbd>2</kbd> | all rear attached devices on/off |
| <kbd>L Alt</kbd>+<kbd>3</kbd> | all front attached devices up/down |
| <kbd>L Alt</kbd>+<kbd>4</kbd> | all front attached devices on/off |
| <kbd>L Alt</kbd>+<kbd>5</kbd> | all rear attached devices unfold/fold |
| <kbd>L Alt</kbd>+<kbd>6</kbd> | all front attached devices unfold/fold |

## What this mod does
* When the game starts, it changes all "motorized" and "controllable" vehicles on the map to default settings: wheel drive mode to "all-wheel (4WD)" and deactivation of both differentials.
* Press <kbd>Ctrl</kbd>+<kbd>Numpad /</kbd> to open the config dialog.
* Press <kbd>R Shift</kbd>+<kbd>Home</kbd> to enable the snap to direction or snap to track assistant.
  * Press & hold <kbd>R Shift</kbd>+<kbd>Home</kbd> one second or longer to disable the snap & track assistant completely.
* Press <kbd>R Ctrl</kbd>+<kbd>End</kbd> to keep your vehicle driving in the current direction or on the current track.
  * Press <kbd>R Ctrl</kbd>+<kbd>Home</kbd> to reverse snap/track direction (e.g. to turn around at end of field).
* Press <kbd>R Ctrl</kbd>+<kbd>Numpad 2</kbd> to calculate a track layout based on current vehicle direction and implement working width.
  * If you now enable snap mode the vehicle will drive on the current marked track.
  * Press <kbd>R Ctrl</kbd>+<kbd>Numpad 4/6</kbd> to adjust the turnover track number (from -5 to 5).
  * Configure headland behavior in configuration menu or via keys.
* Press <kbd>R Ctrl</kbd>+<kbd>Numpad 1</kbd> to (re-)calculate the working width. This will not change the current track layout.
* Press <kbd>Numpad Enter</kbd> to put your vehicle in parking mode. It won't move an inch in this mode.
* On HUD it displays:
  * (When snap/track is enabled) The current snap to angle and current track and turnover number.
  * Damage values in % for controlled vehicle and all its attachments.
  * Fuel fill level for Diesel/AdBlue/Electric/Methane and the current fuel usage rate<sup>1</sup>.
  * The overall kilometer counter of the vehicle or the current trip kilometer.
  * The current status of the differential locks and wheel drive mode.
  * The current engine RPM and temperature<sup>1</sup>.
  * The current mass of the vehicle and the total mass of vehicle and all its attachments and loads.
* Keybindings can be changed in the game options menu.

**<sup>1</sup> In multiplayer games, all clients, except the host, won't display the fuel usage rate and engine temperature correctly due to GIANTS Engine limitations**

## What this mod doesn't (fully) do
* Work on consoles. Buy a PC for proper gaming.

# Português (Brasil)

Esta é uma modificação para o Farming Simulator 25. Ela adiciona um "assistente de traçado" ("GPS") e um recurso de "ajuste para a direção de condução", um freio de estacionamento, bloqueios diferenciais, modos de tração das rodas e controles hidráulicos aprimorados ao seu veículo. Também exibe mais detalhes do veículo no HUD, incluindo um hodômetro/contador de viagem.

\*\*Nota: As únicas fontes válidas de download são o meu site (https://www.majo76.de) e este repositório no Github (https://github.com/ZhooL/FS25_EnhancedVehicle). Todos os outros endereços de download não são validados por mim - então, por favor, use-os com cautela.

(c) 2018-2025 por Majo76 (anteriormente ZhooL). Seja gentil e me credite ao usar este mod ou o código-fonte (ou partes dele) em qualquer lugar. A monetização deste mod é proibida.
Licença: https://creativecommons.org/licenses/by-nc-sa/4.0/

## Known bugs

- Provavelmente muitos... por favor, reporte-os via issues no Github.

## Visão geral do HUD

![HUD overview](/misc/hud_overview_en.png)

## Atalhos de Teclado
| Tecla | Descrição |
| --    | --        |
| <kbd>R Ctrl</kbd>+<kbd>Num /</kbd> | abre o diálogo de configurações para ajustar várias configurações |
| <kbd>Num Enter</kbd> | aplicar/liberar o freio de estacionamento |
| <kbd>R Ctrl</kbd>+<kbd>End</kbd> | ajustar para a direção de condução atual ou para o traçado atual |
| <kbd>R Ctrl</kbd>+<kbd>Home</kbd> | reverter a direção do snap/traçado (180°) (= virar) |
| <kbd>R Shift</kbd>+<kbd>Home</kbd> | mudar o modo operacional (ajustar para direção ou ajustar para traçado)<br/>pressione e segure por um segundo para desativar o assistente de snap |
| <kbd>R Ctrl</kbd>+<kbd>Num 1</kbd> | recalcular a largura de trabalho (por exemplo, largura de pulverização alterada) |
| <kbd>R Ctrl</kbd>+<kbd>Num 2</kbd> | recalcular o layout do traçado (por exemplo, direção alterada ou largura de trabalho alterada) |
| <kbd>R Ctrl</kbd>+<kbd>Num 3</kbd> | alternar entre os diferentes modos de exibição das linhas |
| <kbd>R Ctrl</kbd>+<kbd>Num 4</kbd> / <kbd>Num 6</kbd> | diminuir/aumentar o número de trilhas de virada |
| <kbd>R Ctrl</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | mover o layout do traçado para a esquerda/direita |
| <kbd>R Ctrl</kbd>+<kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | mover a linha de deslocamento do traçado para a esquerda/direita |
| <kbd>R Shift</kbd>+<kbd>Num -</kbd> / <kbd>Num +</kbd> | diminuir/aumentar a largura do traçado |
| <kbd>R Ctrl</kbd>+<kbd>Insert</kbd> / <kbd>Delete</kbd> | mover o veículo uma trilha para a direita/esquerda sem virar |
| <kbd>R Ctrl</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | aumentar/diminuir a direção do snap/traçado em 1° |
| <kbd>R Shift</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | aumentar/diminuir a direção do snap/traçado em 45° |
| <kbd>R Ctrl</kbd>+<kbd>R Shift</kbd>+<kbd>PageUp</kbd> / <kbd>PageDown</kbd> | aumentar/diminuir a direção do snap/traçado em 0.25° |
| <kbd>R Ctrl</kbd>+<kbd>Num *</kbd> | alternar entre os diferentes modos de cabeceira |
| <kbd>R Shift</kbd>+<kbd>Num /</kbd> / <kbd>Num *</kbd> | alternar entre as distâncias da cabeceira |
| <kbd>R Ctrl</kbd>+<kbd>Num 5</kbd> | alternar entre o contador de quilômetros geral ou o contador de quilômetros da viagem.<br/>pressione e segure para resetar o contador de quilômetros da viagem para 0 |
| <kbd>R Ctrl</kbd>+<kbd>Num 7</kbd> | ativar/desativar o bloqueio diferencial do eixo dianteiro |
| <kbd>R Ctrl</kbd>+<kbd>Num 8</kbd> | ativar/desativar o bloqueio diferencial do eixo traseiro |
| <kbd>R Ctrl</kbd>+<kbd>Num 9</kbd> | alternar o modo de tração das rodas entre 4WD (tração nas quatro rodas) ou 2WD (tração nas duas rodas) |
| <kbd>L Alt</kbd>+<kbd>1</kbd> | todos os dispositivos traseiros para cima/baixo |
| <kbd>L Alt</kbd>+<kbd>2</kbd> | todos os dispositivos traseiros ligar/desligar |
| <kbd>L Alt</kbd>+<kbd>3</kbd> | todos os dispositivos dianteiros para cima/baixo |
| <kbd>L Alt</kbd>+<kbd>4</kbd> | todos os dispositivos dianteiros ligar/desligar |
| <kbd>L Alt</kbd>+<kbd>5</kbd> | todos os dispositivos traseiros desdobrar/dobrar |
| <kbd>L Alt</kbd>+<kbd>6</kbd> | todos os dispositivos dianteiros desdobrar/dobrar |

## O que este mod faz

- Quando o jogo começa, ele altera todos os veículos "motorizados" e "controláveis" no mapa para as configurações padrão: modo de tração das rodas para "tração integral (4WD)" e desativação de ambos os diferenciais.
- Pressione <kbd>Ctrl</kbd>+<kbd>Numpad /</kbd> para abrir o diálogo de configurações.
- Pressione <kbd>R Shift</kbd>+<kbd>Home</kbd> para ativar o assistente de snap para direção ou snap para traçado.
  - Pressione e segure <kbd>R Shift</kbd>+<kbd>Home</kbd> por um segundo ou mais para desativar completamente o assistente de snap e traçado.
- Pressione <kbd>R Ctrl</kbd>+<kbd>End</kbd> para manter seu veículo dirigindo na direção atual ou no traçado atual.
  - Pressione <kbd>R Ctrl</kbd>+<kbd>Home</kbd> para reverter a direção do snap/traçado (por exemplo, para virar no final do campo).
- Pressione <kbd>R Ctrl</kbd>+<kbd>Numpad 2</kbd> para calcular um layout de traçado com base na direção atual do veículo e na largura de trabalho do implemento.
  - Se agora você ativar o modo de snap, o veículo seguirá o traçado marcado atual.
  - Pressione <kbd>R Ctrl</kbd>+<kbd>Numpad 4/6</kbd> para ajustar o número de trilhas de virada (de -5 a 5).
  - Configure o comportamento da cabeceira no menu de configuração ou via teclas.
- Pressione <kbd>R Ctrl</kbd>+<kbd>Numpad 1</kbd> para (re)calcular a largura de trabalho. Isso não alterará o layout atual do traçado.
- Pressione <kbd>Numpad Enter</kbd> para colocar seu veículo no modo de estacionamento. Ele não se moverá nem um centímetro neste modo.
- No HUD, ele exibe:
  - (Quando o snap/traçado está ativado) O ângulo atual do snap e o número do traçado e da virada.
  - Valores de dano em % para o veículo controlado e todos os seus implementos.
  - Nível de combustível para Diesel/AdBlue/Eletro/Metano e a taxa atual de consumo de combustível<sup>1</sup>.
  - O contador total de quilômetros do veículo ou o contador de quilômetros da viagem atual.
  - O status atual dos bloqueios diferenciais e do modo de tração das rodas.
  - A rotação atual do motor (RPM) e a temperatura<sup>1</sup>.
  - A massa atual do veículo e a massa total do veículo, seus implementos e cargas.
- Os atalhos de teclado podem ser alterados no menu de opções do jogo.

**<sup>1</sup> Em jogos multiplayer, todos os clientes, exceto o host, não exibirão corretamente a taxa de consumo de combustível e a temperatura do motor devido às limitações do GIANTS Engine.**

## O que este mod não faz (completamente)

- Funcionar em consoles. Compre um PC para uma experiência de jogo adequada.

# Und sonst so / The rest
* Twitch: https://www.twitch.tv/Majo76_ (Freue mich über ein Follow / A follow is much appreciated)
* Instagram: https://www.instagram.com/Majo76__/
* Discord: https://d.majo76.de
* BlueSky: https://bsky.app/profile/majo76.de
* Twitter: https://www.twitter.com/Majo76_ (Es heißt Twitter! / The name is Twitter!)
* HomePage: https://www.majo76.de
* GitHub: https://github.com/ZhooL/FS25_EnhancedVehicle
