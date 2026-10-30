<?php
function addGmailHelp(string $source): string
{
    if (str_contains($source, 'kv-gmail-help')) return $source;
    $html = '<div class="kv-gmail-help" style="margin-top:12px;max-width:460px;line-height:1.5">'
        . '<strong>¿Usas Gmail?</strong><p>Para obtener tu contraseña de aplicación, pulsa este botón e inicia sesión en Google. '
        . 'Necesitas tener activada la verificación en dos pasos. Crea una contraseña para Kits &amp; Vet CRM; '
        . 'después vuelve a esta pestaña y pégala en el campo Contraseña. No uses tu contraseña habitual de Gmail.</p>'
        . '<a class="button" style="display:inline-block;white-space:normal" href="https://myaccount.google.com/apppasswords" '
        . 'target="_blank" rel="noopener noreferrer">Obtener contraseña de aplicación de Google</a>'
        . '<p><small>Abre Google en otra pestaña. Este botón no genera ni guarda la contraseña automáticamente.</small></p></div>';
    return $source . "\n" . '{{if $vardef.name == "mail_smtppass" || $vardef.name == "email_password"}}'
        . $html . '{{/if}}' . "\n";
}

if (($argv[1] ?? '') === '--check') {
    foreach (['mail_smtppass', 'email_password'] as $field) {
        $source = "<?php \$viewdefs=['$field'];";
        $result = addGmailHelp($source);
        if (substr_count($result, 'Obtener contraseña de aplicación de Google') !== 1
            || !str_contains($result, 'https://myaccount.google.com/apppasswords')
            || !str_contains($result, 'target="_blank" rel="noopener noreferrer"')
            || addGmailHelp($result) !== $result) {
            throw new RuntimeException('Gmail help check failed');
        }
    }
    echo "Gmail help check passed: both fields, safe link, idempotent.\n";
    exit;
}
$root = $argv[1] ?? '/var/www/html/public/legacy';
$file = "$root/custom/include/SugarFields/Fields/Password/EditView.tpl";
    $original = "$root/include/SugarFields/Fields/Password/EditView.tpl";
    if (!is_dir(dirname($file)) && !mkdir(dirname($file), 0755, true)) throw new RuntimeException('Cannot create template directory');
    if (!file_exists($file)) {
        if (!copy($original, $file)) throw new RuntimeException('Cannot copy password template');
    }
    $source = file_get_contents($file);
    if ($source === false) throw new RuntimeException('Cannot read ' . $file);
    $result = addGmailHelp($source);
    if ($result !== $source && file_put_contents($file, $result) === false) throw new RuntimeException('Cannot write ' . $file);
    echo "Gmail help installed: inbound and outbound password fields\n";
