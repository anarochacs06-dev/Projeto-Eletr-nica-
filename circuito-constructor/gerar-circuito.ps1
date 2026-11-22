# Gera o arquivo do Constructor Virtual (formato "Version 0.9.7") para o
# decodificador 2 entre 5 -> Johnson:
#   S4 = A + D'E'   S3 = AB' + A'BE'   S2 = A'B + AB'C'   S1 = A'E' + EC'D'   S0 = A'D' + A'E'
# Uso:  powershell -File gerar-circuito.ps1 [-Saida decodificador-2de5-johnson.txt]
param([string]$Saida = (Join-Path $PSScriptRoot 'decodificador-2de5-johnson.txt'))

# ---------- placas (tipo x y largura altura nodoBase id) ----------
# tipo 4 = fonte DC, 0 = protoboard, 1 = interruptores, 3 = LEDs, 5 = placa padrão do programa
$boards = @(
  ' 4 8 196 77 128 0 1',
  ' 5 80 400 206 81 2 2',
  ' 0 104 128 877 276 8 3',
  ' 1 173 462 206 81 140 4',
  ' 3 343 31 203 58 150 5'
)
$PB = 3; $SWB = 4; $LEDB = 5

# ---------- geometria da protoboard (posicionada em 104,128) ----------
function ColX([int]$c) { 118 + 13 * $c }                # coluna 1..64
$TopRows = @(194, 207, 220, 233)                        # A B C D  (E = pinos do CI)
$BotRows = @(337, 324, 311, 298)                        # J I H G  (F = pinos do CI)
$RailVcc = 155; $RailVccBot = 376; $RailGndBot = 389
function SwPort([int]$k)  { @((173 + 56 + 19 * $k), 473) }   # interruptor k (0 = mais à esquerda)
function LedPort([int]$k) { @((343 + 46 + 20 * $k), 75) }    # LED k (0 = mais à esquerda)

# ---------- CIs: nome, código no arquivo, coluna do pino 1 ----------
$chips = [ordered]@{
  U1 = @{ code = 7004; L = 6  }   # 7404  inversores
  U2 = @{ code = 7008; L = 15 }   # 7408  AND 2 entradas
  U3 = @{ code = 7008; L = 24 }   # 7408  AND 2 entradas
  U4 = @{ code = 7011; L = 33 }   # 7411  AND 3 entradas
  U5 = @{ code = 7032; L = 42 }   # 7432  OR 2 entradas
  U6 = @{ code = 7032; L = 51 }   # 7432  OR 2 entradas
}

# furos livres por faixa (coluna + lado)
$free = @{}
function Take([int]$col, [string]$side) {
  $key = "$col$side"
  if (-not $free.ContainsKey($key)) { $free[$key] = [System.Collections.ArrayList]@($(if ($side -eq 'T') { $TopRows } else { $BotRows })) }
  if ($free[$key].Count -eq 0) { throw "Sem furos livres na coluna $col lado $side" }
  $y = $free[$key][0]; $free[$key].RemoveAt(0)
  @((ColX $col), $y)
}
function PinStrip([string]$ref) {
  $u, $p = $ref.Split('.'); $p = [int]$p; $L = $chips[$u].L
  if ($p -le 7) { @(($L + $p - 1), 'B') } else { @(($L + 14 - $p), 'T') }
}

$wires = New-Object System.Collections.ArrayList
$lane = 0
function Add-Wire($color, $a, $b, [int]$ba, [int]$bb, $mid) {
  # 6 pontos: início, início, dobra 1, dobra 2, fim, fim
  $pts = @($a[0], $a[1], $a[0], $a[1], $mid[0], $mid[1], $mid[2], $mid[3], $b[0], $b[1], $b[0], $b[1])
  [void]$wires.Add((' {0} 5 {1} 0 {2} 0 {3}' -f $color, ($pts -join ' '), $ba, $bb))
}
function Wire-PB($color, $h1, $h2) {
  # dentro da protoboard: sobe/desce até uma "via" entre as fileiras e segue na horizontal
  $script:lane = ($script:lane + 1) % 4
  if ($h1[1] -eq $h2[1]) { $y = $h1[1] + $(if ($h1[1] -lt 260) { -4 - 2 * $script:lane } else { 4 + 2 * $script:lane }) }
  else { $y = $h2[1] }
  Add-Wire $color $h1 $h2 $PB $PB @($h1[0], $y, $h2[0], $y)
}

# ---------- alimentação (fonte -> barramentos, placas -> barramentos) ----------
$power = @(
  ' 65793 5 157 142 157 142 107 142 107 270 69 270 69 270 0 3 0 1',
  ' 65793 5 157 389 157 389 69 389 69 389 69 309 69 309 0 3 0 1',
  ' 255 5 69 210 69 210 69 155 69 155 157 155 157 155 0 1 0 3',
  ' 255 5 69 223 69 223 96 223 96 376 157 376 157 376 0 1 0 3',
  ' 255 5 188 473 188 473 182 473 182 376 170 376 170 376 0 4 0 3',
  ' 0 5 170 389 170 389 165 389 165 531 188 531 188 531 0 3 0 4',
  ' 65793 5 354 68 354 68 354 68 326 68 326 142 326 142 0 5 0 3'
)
foreach ($p in $power) { [void]$wires.Add($p) }
foreach ($u in $chips.Keys) {
  $L = $chips[$u].L
  $h = Take $L 'T';         Add-Wire 255   $h @((ColX $L), $RailVcc) $PB $PB @($h[0], $h[1], $h[0], $RailVcc)
  $h = Take ($L + 6) 'B';   Add-Wire 65793 $h @((ColX ($L + 6)), $RailGndBot) $PB $PB @($h[0], $h[1], $h[0], $RailGndBot)
}

# ---------- netlist ----------
# cores COLORREF (0x00BBGGRR)
$Y = 65535; $G = 65280; $Cy = 16776960; $O = 33023; $P = 12615935; $T = 8421631; $Bl = 16711680
$nets = @(
  @{ c = $Y;  sw = 0; pins = 'U1.1','U2.4','U4.3','U5.1' },             # A
  @{ c = $G;  sw = 1; pins = 'U1.3','U2.10','U4.2' },                    # B
  @{ c = $Cy; sw = 2; pins = 'U1.5' },                                   # C
  @{ c = $O;  sw = 3; pins = 'U1.9' },                                   # D
  @{ c = $P;  sw = 4; pins = 'U1.11','U4.9' },                           # E
  @{ c = $Y;  pins = 'U1.2','U2.9','U2.12','U3.1','U4.1' },              # A'
  @{ c = $G;  pins = 'U1.4','U2.5','U4.4' },                             # B'
  @{ c = $Cy; pins = 'U1.6','U4.5','U4.10' },                            # C'
  @{ c = $O;  pins = 'U1.8','U2.1','U3.2','U4.11' },                     # D'
  @{ c = $P;  pins = 'U1.10','U2.2','U2.13','U4.13' },                   # E'
  @{ c = $T;  pins = 'U2.3','U5.2' },                                    # D'E'
  @{ c = $T;  pins = 'U2.6','U5.4' },                                    # AB'
  @{ c = $T;  pins = 'U2.8','U5.9' },                                    # A'B
  @{ c = $T;  pins = 'U2.11','U5.12','U6.2' },                           # A'E'
  @{ c = $T;  pins = 'U3.3','U6.1' },                                    # A'D'
  @{ c = $T;  pins = 'U4.12','U5.5' },                                   # A'BE'
  @{ c = $T;  pins = 'U4.6','U5.10' },                                   # AB'C'
  @{ c = $T;  pins = 'U4.8','U5.13' },                                   # EC'D'
  @{ c = $Bl; led = 0; pins = 'U5.3' },                                  # S4
  @{ c = $Bl; led = 1; pins = 'U5.6' },                                  # S3
  @{ c = $Bl; led = 2; pins = 'U5.8' },                                  # S2
  @{ c = $Bl; led = 3; pins = 'U5.11' },                                 # S1
  @{ c = $Bl; led = 4; pins = 'U6.3' }                                   # S0
)

$swLane = 0; $ledLane = 0
foreach ($n in $nets) {
  $strips = @($n.pins | ForEach-Object { , (PinStrip $_) })
  if ($null -ne $n.sw) {
    # interruptor -> primeiro pino (furo inferior)
    $s = $strips[0]; $h = Take $s[0] $s[1]; $sp = SwPort $n.sw
    $ly = 412 + 9 * $swLane; $swLane++
    Add-Wire $n.c $sp $h $SWB $PB @($sp[0], $ly, $h[0], $ly)
  }
  for ($i = 0; $i -lt $strips.Count - 1; $i++) {
    $h1 = Take $strips[$i][0] $strips[$i][1]
    $h2 = Take $strips[$i + 1][0] $strips[$i + 1][1]
    Wire-PB $n.c $h1 $h2
  }
  if ($null -ne $n.led) {
    $s = $strips[$strips.Count - 1]; $h = Take $s[0] $s[1]; $lp = LedPort $n.led
    $ly = 96 + 6 * $ledLane; $ledLane++
    Add-Wire $n.c $h $lp $PB $LEDB @($h[0], $ly, $lp[0], $ly)
  }
}

# ---------- arquivo ----------
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('Version 0.9.7'); [void]$lines.Add("$($boards.Count)")
$boards | ForEach-Object { [void]$lines.Add($_) }
[void]$lines.Add(' 0'); [void]$lines.Add("$($wires.Count)")
$wires | ForEach-Object { [void]$lines.Add($_) }
[void]$lines.Add("$($chips.Count)")
foreach ($u in $chips.Keys) { $L = $chips[$u].L; [void]$lines.Add((' {0} 1 14 {1} 246 5 0 0 7076 {2}' -f $chips[$u].code, (112 + 13 * $L), $PB)) }
[IO.File]::WriteAllText($Saida, (($lines -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)
"Gerado: $Saida  ($($wires.Count) fios, $($chips.Count) CIs)"
