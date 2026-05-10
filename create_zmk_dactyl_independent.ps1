<#
.SYNOPSIS
  Создаёт полный шаблон ZMK-конфига для двух независимых половин Dactyl 4x6 на nRF52840/SuperMini/nice_nano_v2.

.DESCRIPTION
  Запускается в ПУСТОЙ папке или в папке будущего репозитория zmk-config.
  Скрипт создаёт структуру:
    .github/workflows/build.yml
    config/build.yaml
    config/west.yml
    config/dactyl_left.conf
    config/dactyl_left.keymap
    config/dactyl_right.conf
    config/dactyl_right.keymap
    config/boards/shields/dactyl_left/*
    config/boards/shields/dactyl_right/*
    README.md

  Архитектура: НЕ split central/peripheral, а две независимые BLE-клавиатуры:
    - Dactyl Left
    - Dactyl Right

  По умолчанию board = nice_nano_v2, потому что большинство SuperMini nRF52840 совместимы по ZMK с nice_nano_v2.

.PARAMETER Force
  Перезаписывать существующие файлы.

.PARAMETER Zip
  После создания файлов собрать zip-архив zmk-dactyl-independent-config.zip.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\create_zmk_dactyl_independent.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\create_zmk_dactyl_independent.ps1 -Force -Zip
#>

param(
    [switch]$Force,
    [switch]$Zip
)

$ErrorActionPreference = "Stop"

function New-DirIfMissing {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-TextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir) { New-DirIfMissing -Path $dir }

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        Write-Host "SKIP exists: $Path    используйте -Force для перезаписи" -ForegroundColor Yellow
        return
    }

    # UTF-8 без BOM, корректно для ZMK/YAML/DTS.
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath .).Path + [System.IO.Path]::DirectorySeparatorChar + $Path, $Content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "WRITE: $Path" -ForegroundColor Green
}

Write-Host "Создаю ZMK-конфиг для независимых половин Dactyl 4x6..." -ForegroundColor Cyan

New-DirIfMissing -Path ".github/workflows"
New-DirIfMissing -Path "config/boards/shields/dactyl_left"
New-DirIfMissing -Path "config/boards/shields/dactyl_right"

Write-TextFile -Path ".gitignore" -Content @'
# ZMK / west / build artifacts
build/
zephyr/
modules/
tools/
.zmk/
.west/
*.uf2
*.hex
*.elf
*.bin
*.map
*.zip
.DS_Store
Thumbs.db
'@

Write-TextFile -Path ".github/workflows/build.yml" -Content @'
name: Build ZMK firmware

on:
  workflow_dispatch:
  push:
    paths:
      - "config/**"
      - ".github/workflows/build.yml"

jobs:
  build:
    uses: zmkfirmware/zmk/.github/workflows/build-user-config.yml@main
'@

Write-TextFile -Path "config/build.yaml" -Content @'
# Две независимые Bluetooth-клавиатуры, НЕ split central/peripheral.
# Если ваша SuperMini nRF52840 не совместима с nice_nano_v2, замените board здесь.
include:
  - board: nice_nano_v2
    shield: dactyl_left
  - board: nice_nano_v2
    shield: dactyl_right
'@

Write-TextFile -Path "config/west.yml" -Content @'
manifest:
  remotes:
    - name: zmkfirmware
      url-base: https://github.com/zmkfirmware
  projects:
    - name: zmk
      remote: zmkfirmware
      revision: main
      import: app/west.yml
  self:
    path: config
'@

Write-TextFile -Path "config/dactyl_left.conf" -Content @'
# Левая половина как самостоятельная BLE/USB HID-клавиатура.
CONFIG_ZMK_KEYBOARD_NAME="Dactyl Left"

# Bluetooth и USB. USB полезен для отладки и аварийной работы проводом.
CONFIG_ZMK_BLE=y
CONFIG_ZMK_USB=y

# Отчёт батареи в ОС, если плата/bootloader/аккумуляторная схема это поддерживают.
CONFIG_ZMK_BATTERY_REPORTING=y

# Сон для экономии аккумулятора. У вас есть тумблер питания, но сон всё равно полезен.
CONFIG_ZMK_SLEEP=y
CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=900000

# Обычно помогает дальности/стабильности BLE на nRF52840. Если сборка ругнётся — закомментируйте.
CONFIG_BT_CTLR_TX_PWR_PLUS_8=y
'@

Write-TextFile -Path "config/dactyl_right.conf" -Content @'
# Правая половина как самостоятельная BLE/USB HID-клавиатура.
CONFIG_ZMK_KEYBOARD_NAME="Dactyl Right"

CONFIG_ZMK_BLE=y
CONFIG_ZMK_USB=y
CONFIG_ZMK_BATTERY_REPORTING=y
CONFIG_ZMK_SLEEP=y
CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=900000
CONFIG_BT_CTLR_TX_PWR_PLUS_8=y
'@

Write-TextFile -Path "config/boards/shields/dactyl_left/Kconfig.shield" -Content @'
config SHIELD_DACTYL_LEFT
    def_bool $(shields_list_contains,dactyl_left)
'@

Write-TextFile -Path "config/boards/shields/dactyl_left/Kconfig.defconfig" -Content @'
if SHIELD_DACTYL_LEFT

config ZMK_KEYBOARD_NAME
    default "Dactyl Left"

endif
'@

Write-TextFile -Path "config/boards/shields/dactyl_left/dactyl_left.zmk.yml" -Content @'
file_format: "1"
id: dactyl_left
name: Dactyl Left Independent
type: shield
url: https://www.thingiverse.com/thing:6556207
requires:
  - nice_nano_v2
features:
  - keys
'@

Write-TextFile -Path "config/boards/shields/dactyl_left/dactyl_left.overlay" -Content @'
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/zmk/matrix_transform.h>

/ {
    chosen {
        zmk,kscan = &kscan0;
        zmk,matrix_transform = &default_transform;
    };

    default_transform: keymap_transform_0 {
        compatible = "zmk,matrix-transform";
        columns = <6>;
        rows = <4>;
        map = <
            RC(0,0) RC(0,1) RC(0,2) RC(0,3) RC(0,4) RC(0,5)
            RC(1,0) RC(1,1) RC(1,2) RC(1,3) RC(1,4) RC(1,5)
            RC(2,0) RC(2,1) RC(2,2) RC(2,3) RC(2,4) RC(2,5)
            RC(3,0) RC(3,1) RC(3,2) RC(3,3) RC(3,4) RC(3,5)
        >;
    };

    kscan0: kscan {
        compatible = "zmk,kscan-gpio-matrix";
        diode-direction = "col2row";

        /*
         * Левая половина, ваши пины:
         * row0 - 100 => P1.00
         * row1 - 011 => P0.11
         * row2 - 104 => P1.04
         * row3 - 106 => P1.06
         * col0 - 009 => P0.09
         * col1 - 010 => P0.10
         * col2 - 111 => P1.11
         * col3 - 113 => P1.13
         * col4 - 115 => P1.15
         * col5 - 002 => P0.02
         */
        row-gpios =
            <&gpio1 0 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio0 11 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio1 4 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio1 6 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>;

        col-gpios =
            <&gpio0 9 GPIO_ACTIVE_HIGH>,
            <&gpio0 10 GPIO_ACTIVE_HIGH>,
            <&gpio1 11 GPIO_ACTIVE_HIGH>,
            <&gpio1 13 GPIO_ACTIVE_HIGH>,
            <&gpio1 15 GPIO_ACTIVE_HIGH>,
            <&gpio0 2 GPIO_ACTIVE_HIGH>;
    };
};
'@

Write-TextFile -Path "config/boards/shields/dactyl_right/Kconfig.shield" -Content @'
config SHIELD_DACTYL_RIGHT
    def_bool $(shields_list_contains,dactyl_right)
'@

Write-TextFile -Path "config/boards/shields/dactyl_right/Kconfig.defconfig" -Content @'
if SHIELD_DACTYL_RIGHT

config ZMK_KEYBOARD_NAME
    default "Dactyl Right"

endif
'@

Write-TextFile -Path "config/boards/shields/dactyl_right/dactyl_right.zmk.yml" -Content @'
file_format: "1"
id: dactyl_right
name: Dactyl Right Independent
type: shield
url: https://www.thingiverse.com/thing:6556207
requires:
  - nice_nano_v2
features:
  - keys
'@

Write-TextFile -Path "config/boards/shields/dactyl_right/dactyl_right.overlay" -Content @'
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/zmk/matrix_transform.h>

/ {
    chosen {
        zmk,kscan = &kscan0;
        zmk,matrix_transform = &default_transform;
    };

    default_transform: keymap_transform_0 {
        compatible = "zmk,matrix-transform";
        columns = <6>;
        rows = <4>;
        map = <
            RC(0,0) RC(0,1) RC(0,2) RC(0,3) RC(0,4) RC(0,5)
            RC(1,0) RC(1,1) RC(1,2) RC(1,3) RC(1,4) RC(1,5)
            RC(2,0) RC(2,1) RC(2,2) RC(2,3) RC(2,4) RC(2,5)
            RC(3,0) RC(3,1) RC(3,2) RC(3,3) RC(3,4) RC(3,5)
        >;
    };

    kscan0: kscan {
        compatible = "zmk,kscan-gpio-matrix";
        diode-direction = "col2row";

        /*
         * Правая половина, ваши пины:
         * row0 - 106 => P1.06
         * row1 - 104 => P1.04
         * row2 - 011 => P0.11
         * row3 - 100 => P1.00
         * col0 - 009 => P0.09
         * col1 - 010 => P0.10
         * col2 - 111 => P1.11
         * col3 - 113 => P1.13
         * col4 - 115 => P1.15
         * col5 - 002 => P0.02
         */
        row-gpios =
            <&gpio1 6 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio1 4 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio0 11 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>,
            <&gpio1 0 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>;

        col-gpios =
            <&gpio0 9 GPIO_ACTIVE_HIGH>,
            <&gpio0 10 GPIO_ACTIVE_HIGH>,
            <&gpio1 11 GPIO_ACTIVE_HIGH>,
            <&gpio1 13 GPIO_ACTIVE_HIGH>,
            <&gpio1 15 GPIO_ACTIVE_HIGH>,
            <&gpio0 2 GPIO_ACTIVE_HIGH>;
    };
};
'@

Write-TextFile -Path "config/dactyl_left.keymap" -Content @'
#include <behaviors.dtsi>
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/bt.h>
#include <dt-bindings/zmk/outputs.h>
#include <dt-bindings/zmk/reset.h>

#define BASE 0
#define NUM  1
#define SYS  2

/ {
    macros {
        /* Переключение языка Windows: Left Shift + Left Alt. */
        lang_sw: lang_sw {
            compatible = "zmk,behavior-macro";
            #binding-cells = <0>;
            bindings =
                <&macro_press &kp LSHFT &kp LALT>,
                <&macro_release &kp LALT &kp LSHFT>;
        };
    };

    keymap {
        compatible = "zmk,keymap";

        base_layer {
            label = "BASE";
            bindings = <
                &kp ESC    &kp Q      &kp W      &kp E      &kp R      &kp T
                &kp TAB    &kp A      &kp S      &kp D      &kp F      &kp G
                &kp LCTRL  &kp Z      &kp X      &kp C      &kp V      &kp B
                &kp LGUI   &kp LALT   &lang_sw   &kp LSHFT  &kp SPACE  &mo NUM
            >;
        };

        num_layer {
            label = "NUM";
            bindings = <
                &kp GRAVE  &kp N1     &kp N2     &kp N3     &kp N4     &kp N5
                &mo SYS    &kp EXCL   &kp AT     &kp HASH   &kp DLLR   &kp PRCNT
                &kp LCTRL  &kp LBKT   &kp RBKT   &kp LPAR   &kp RPAR   &kp MINUS
                &kp LGUI   &kp LALT   &lang_sw   &kp LSHFT  &kp SPACE  &trans
            >;
        };

        sys_layer {
            label = "SYS";
            bindings = <
                &bootloader       &sys_reset       &kp C_MUTE       &kp C_VOL_DN     &kp C_VOL_UP       &kp C_PLAY_PAUSE
                &out OUT_USB      &out OUT_BLE     &bt BT_SEL 0     &bt BT_SEL 1     &bt BT_SEL 2       &bt BT_CLR
                &none             &none            &bt BT_SEL 3     &bt BT_SEL 4     &bt BT_NXT         &none
                &trans            &trans           &trans           &trans           &trans             &trans
            >;
        };
    };
};
'@

Write-TextFile -Path "config/dactyl_right.keymap" -Content @'
#include <behaviors.dtsi>
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/bt.h>
#include <dt-bindings/zmk/outputs.h>
#include <dt-bindings/zmk/reset.h>

#define BASE 0
#define NUM  1
#define SYS  2

/ {
    macros {
        /* Переключение языка Windows: Left Shift + Left Alt. */
        lang_sw: lang_sw {
            compatible = "zmk,behavior-macro";
            #binding-cells = <0>;
            bindings =
                <&macro_press &kp LSHFT &kp LALT>,
                <&macro_release &kp LALT &kp LSHFT>;
        };
    };

    keymap {
        compatible = "zmk,keymap";

        base_layer {
            label = "BASE";
            bindings = <
                &kp Y      &kp U      &kp I      &kp O      &kp P       &kp BSPC
                &kp H      &kp J      &kp K      &kp L      &kp SEMI    &kp SQT
                &kp N      &kp M      &kp COMMA  &kp DOT    &kp FSLH    &kp ENTER
                &mo NUM    &kp SPACE  &kp RSHFT  &lang_sw   &kp LALT    &kp LGUI
            >;
        };

        num_layer {
            label = "NUM";
            bindings = <
                &kp N6     &kp N7     &kp N8     &kp N9     &kp N0      &kp DEL
                &kp CARET  &kp AMPS   &kp STAR   &kp MINUS  &kp EQUAL   &kp BSLH
                &kp LEFT   &kp DOWN   &kp UP     &kp RIGHT  &kp FSLH    &kp ENTER
                &trans     &kp SPACE  &kp RSHFT  &lang_sw   &kp LALT    &mo SYS
            >;
        };

        sys_layer {
            label = "SYS";
            bindings = <
                &bt BT_SEL 0     &bt BT_SEL 1      &bt BT_SEL 2      &bt BT_SEL 3       &bt BT_SEL 4       &bt BT_CLR
                &bt BT_NXT       &out OUT_BLE      &out OUT_USB      &bootloader        &sys_reset         &none
                &kp C_PREV       &kp C_PLAY_PAUSE  &kp C_NEXT        &kp C_MUTE         &kp C_VOL_DN       &kp C_VOL_UP
                &trans           &trans            &trans            &trans             &trans             &trans
            >;
        };
    };
};
'@

Write-TextFile -Path "README.md" -Content @'
# ZMK Dactyl 4x6 — две независимые половины на nRF52840

Эта папка — готовый `zmk-config` для клавиатуры Dactyl 4x6 из двух независимых Bluetooth-половин.

## Архитектура

Это **не** классический ZMK split `central/peripheral`.

Собираются две отдельные клавиатуры:

- `Dactyl Left`
- `Dactyl Right`

Обе подключаются к Windows одновременно как две независимые BLE HID-клавиатуры.

## Board

По умолчанию используется:

```yaml
board: nice_nano_v2
```

Для большинства SuperMini nRF52840 это самый частый совместимый вариант. Если ваша плата требует другого board, замените его в:

```text
config/build.yaml
```

## Пины

Диоды указаны как:

```dts
diode-direction = "col2row";
```

Левая половина:

```text
row0 P1.00
row1 P0.11
row2 P1.04
row3 P1.06
col0 P0.09
col1 P0.10
col2 P1.11
col3 P1.13
col4 P1.15
col5 P0.02
```

Правая половина:

```text
row0 P1.06
row1 P1.04
row2 P0.11
row3 P1.00
col0 P0.09
col1 P0.10
col2 P1.11
col3 P1.13
col4 P1.15
col5 P0.02
```

## Слои

- `BASE` — печать EN/RU. Русский ввод работает через раскладку Windows.
- `NUM` — цифры, символы, навигация.
- `SYS` — Bluetooth, USB/BLE output, reset, bootloader, media.

Переключение языка Windows: `Left Shift + Left Alt`, выведено отдельной клавишей `lang_sw`.

## Сборка в GitHub Actions

1. Создайте пустой репозиторий, например `zmk-config`.
2. Скопируйте эти файлы в корень репозитория.
3. Выполните:

```powershell
git add .
git commit -m "Add independent Dactyl 4x6 ZMK config"
git push
```

4. Откройте вкладку `Actions`.
5. Скачайте artifact после успешной сборки.
6. Прошейте левую половину файлом для `dactyl_left`, правую — файлом для `dactyl_right`.

## Прошивка UF2

1. Подключите половину по USB.
2. Дважды нажмите `RST`.
3. Должен появиться UF2-диск.
4. Скопируйте соответствующий `.uf2` файл.
5. Повторите для второй половины.

## Подключение к Windows

1. Удалите старые Bluetooth-записи клавиатуры, если они были.
2. Включите левую половину и подключите `Dactyl Left`.
3. Включите правую половину и подключите `Dactyl Right`.
4. Обе половины должны работать одновременно.

## Если сборка упала

Чаще всего причины такие:

1. Ваша SuperMini не совместима с `nice_nano_v2`.
2. В текущем ZMK изменилось имя какого-то keycode.
3. Нужно отключить строку:

```text
CONFIG_BT_CTLR_TX_PWR_PLUS_8=y
```

4. Нужно уточнить направление диодов или подтяжки.

Если клавиши нажимаются не в тех местах — нужно менять `matrix_transform` или порядок строк/колонок.
'@

if ($Zip) {
    $zipPath = "zmk-dactyl-independent-config.zip"
    if (Test-Path -LiteralPath $zipPath) {
        if ($Force) {
            Remove-Item -LiteralPath $zipPath -Force
        } else {
            Write-Host "ZIP exists: $zipPath    используйте -Force для перезаписи" -ForegroundColor Yellow
            Write-Host "Готово." -ForegroundColor Cyan
            exit 0
        }
    }

    $items = @(".github", "config", ".gitignore", "README.md") | Where-Object { Test-Path -LiteralPath $_ }
    Compress-Archive -Path $items -DestinationPath $zipPath
    Write-Host "ZIP: $zipPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Готово." -ForegroundColor Cyan
Write-Host "Дальше:" -ForegroundColor Cyan
Write-Host "  git init"
Write-Host "  git add ."
Write-Host "  git commit -m 'Add independent Dactyl 4x6 ZMK config'"
Write-Host "  git branch -M main"
Write-Host "  git remote add origin https://github.com/BejoV/zmk-config.git"
Write-Host "  git push -u origin main"
Write-Host ""
Write-Host "Потом откройте GitHub Actions и скачайте UF2-прошивки." -ForegroundColor Cyan
