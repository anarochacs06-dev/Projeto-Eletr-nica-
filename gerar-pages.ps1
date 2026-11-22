# Gera o index.html do GitHub Pages a partir de simulador-decodificador.html.
# O simulador é escrito sem <html>/<head>/<body> (formato de artefato do Claude);
# este script acrescenta a estrutura completa e o reset básico de estilos.
# Uso: powershell -File gerar-pages.ps1   (rode de novo sempre que mudar o simulador)
$raiz = $PSScriptRoot
$conteudo = [IO.File]::ReadAllText((Join-Path $raiz 'simulador-decodificador.html'), [Text.Encoding]::UTF8)

$cabecalho = @'
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="description" content="Simulador interativo do decodificador de código 2 entre 5 para código Johnson, com montagem passo a passo na protoboard. IFMT Campus Cuiabá, Eletrônica Digital.">
<style>
:root { color-scheme: light; padding-top: env(safe-area-inset-top, 0px); padding-bottom: env(safe-area-inset-bottom, 0px); }
body { margin: 0; font: 14px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
img { max-width: 100%; }
[hidden] { display: none !important; }
</style>
'@

# <title>, <meta>, <link> e <style> do simulador vão para o <head>; o resto para o <body>
$i = $conteudo.IndexOf('<div class="wrap">')
if ($i -lt 0) { throw 'Não encontrei <div class="wrap"> em simulador-decodificador.html' }
$head = $conteudo.Substring(0, $i).Trim()
$body = $conteudo.Substring($i).Trim()

$html = $cabecalho + $head + "`n</head>`n<body>`n" + $body + "`n</body>`n</html>`n"
[IO.File]::WriteAllText((Join-Path $raiz 'index.html'), $html, (New-Object Text.UTF8Encoding $false))
"index.html gerado ({0:N0} bytes)" -f (Get-Item (Join-Path $raiz 'index.html')).Length
