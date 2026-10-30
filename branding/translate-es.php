<?php
// Translate literal display values only. Keys, placeholders and source comments stay intact.
$translations = [];
foreach (explode("\n", trim(<<<'TEXT'
Save=Guardar
Save Changes=Guardar cambios
Save And Continue=Guardar y continuar
Save & Create New=Guardar y crear otro
Cancel=Cancelar
Filter=Filtrar
Columns=Columnas
Search=Buscar
Search Results=Resultados de búsqueda
Create=Crear
Delete=Eliminar
Delete Record=Eliminar registro
Delete Draft=Eliminar borrador
Edit=Editar
View=Ver
View Summary=Ver resumen
Select=Seleccionar
Select Contact=Seleccionar contacto
Select User=Seleccionar usuario
Select Account=Seleccionar cuenta
Select File=Seleccionar archivo
Clear=Limpiar
Clear User=Quitar usuario
Clear Formatting=Limpiar formato
Show=Mostrar
Next=Siguiente
Previous=Anterior
First=Primera
Last=Última
First Page=Primera página
Previous Page=Página anterior
Next Page=Página siguiente
Last Page=Última página
Back=Volver
Back to top=Volver arriba
Back To Top=Volver arriba
Quick Create=Creación rápida
Recently Viewed=Vistos recientemente
Recently viewed=Vistos recientemente
Language=Idioma
User Language=Idioma del usuario
Username=Usuario
User Name=Nombre de usuario
Password=Contraseña
Actions=Acciones
Action=Acción
Confirm=Confirmar
Close=Cerrar
Close and Create New=Cerrar y crear otro
Add=Agregar
Remove=Quitar
Update=Actualizar
Export=Exportar
Import=Importar
Print=Imprimir
Loading=Cargando
Loading...=Cargando...
Required=Obligatorio
Name=Nombre
Overview=Resumen
OVERVIEW=RESUMEN
Primary=Principal
Primary Address=Dirección principal
PRIMARY ADDRESS=DIRECCIÓN PRINCIPAL
Primary Address Street=Calle de dirección principal
Primary Address Postal Code=Código postal de dirección principal
Primary Address City=Ciudad de dirección principal
Primary Address State=Provincia de dirección principal
Primary Address Country=País de dirección principal
Other Address=Otra dirección
OTHER ADDRESS=OTRA DIRECCIÓN
First Name=Nombre
Last Name=Apellidos
Mobile=Móvil
Department=Departamento
Invalid=No válido
Billing Address=Dirección de facturación
BILLING ADDRESS=DIRECCIÓN DE FACTURACIÓN
Billing Street=Calle de facturación
Billing Postal Code=Código postal de facturación
Billing City=Ciudad de facturación
Billing State=Provincia de facturación
Billing Country=País de facturación
Shipping Address=Dirección de envío
SHIPPING ADDRESS=DIRECCIÓN DE ENVÍO
Shipping Street=Calle de envío
Shipping Postal Code=Código postal de envío
Shipping City=Ciudad de envío
Shipping State=Provincia de envío
Shipping Country=País de envío
City=Ciudad
Address City=Ciudad
Address=Dirección
Country=País
State=Provincia
Postal Code=Código postal
No Recently Viewed Items=Sin elementos vistos recientemente
Subject=Asunto
Related to=Relacionado con
Related To=Relacionado con
Start Date=Fecha de inicio
End Date=Fecha de finalización
Due Date=Fecha de vencimiento
Date Created=Fecha de creación
Date Modified=Fecha de modificación
Accept?=¿Aceptar?
Status=Estado
Account Name=Nombre de cuenta
Amount=Importe
Opportunity Amount=Importe de oportunidad
Sales Stage=Etapa de venta
Prospecting=Prospección
Existing Business=Negocio existente
New Business=Nuevo negocio
Probability (%)=Probabilidad (%)
Next Step=Siguiente paso
Campaign=Campaña
Expected Close Date=Fecha prevista de cierre
Type=Tipo
Website=Sitio web
Phone=Teléfono
Office Phone=Teléfono de oficina
Any Phone=Cualquier teléfono
Any Address=Cualquier dirección
Industry=Sector
Direction=Dirección
Navigate to first page=Ir a primera página
Navigate to last page=Ir a última página
Select Action Menu=Seleccionar menú de acciones
Mobile Phone=Teléfono móvil
Description=Descripción
Assigned=Asignado
Assigned to=Asignado a
Assigned To=Asignado a
Assigned User=Usuario asignado
Assigned User Name=Nombre del usuario asignado
Created By=Creado por
Modified By=Modificado por
Email=Correo electrónico
Emails=Correos electrónicos
e-Mail=Correo electrónico
Email Address=Dirección de correo electrónico
Email Addresses=Direcciones de correo electrónico
Email Settings=Configuración de correo electrónico
Compose Email=Redactar correo electrónico
Archive Email=Archivar correo electrónico
Email as PDF=Enviar PDF por correo electrónico
New Email=Nuevo correo electrónico
Inbound Email=Correo entrante
Outbound Email=Correo saliente
Send Test Email=Enviar correo de prueba
Email sent successfully=Correo enviado correctamente
Show Cc=Mostrar Cc
Show Bcc=Mostrar Cco
Leads=Clientes potenciales
Lead=Cliente potencial
Dashboard=Panel
Administrator=Administrador
Administration=Administración
Create Case=Crear caso
Last Month=Mes pasado
Import vCard=Importar vCard
New Survey Email=Nuevo correo de encuesta
New Transactional Email=Nuevo correo transaccional
New Marketing Email=Nuevo correo de marketing
Send Next Batch of Queued Emails=Enviar siguiente lote de correos pendientes
Send Next Batch of Queued Campaign Emails?=¿Enviar siguiente lote de correos de campaña pendientes?
Apply new Email Template? (This will override your current email body and subject field)=¿Aplicar nueva plantilla de correo? (Se reemplazarán el mensaje y el asunto actuales)
Are you sure you wish to discard this Email? (Changes will be lost)=¿Desea descartar este correo? (Se perderán los cambios)
Error retrieving record. This record may be deleted or you may not be authorized to view it.=No se pudo obtener el registro. Puede haberse eliminado o no tiene permiso para verlo.
Email is no longer a draft.=El correo ya no es un borrador.
Last successful run=Última ejecución correcta
Last user to run schedulers=Último usuario que ejecutó las tareas programadas
Unable to connect to SMTP server with the current Outbound Email settings.=No se puede conectar al servidor SMTP con la configuración de correo saliente actual.
Outbound Email Account not correctly configured.=La cuenta de correo saliente no está configurada correctamente.
Unable to retrieve Default Outbound Email=No se pudo obtener la cuenta predeterminada de correo saliente
Add SuiteCRM Dashlets=Agregar paneles
SuiteCRM Dashlet Added=Panel agregado
Are you sure you want to remove this SuiteCRM Dashlet?=¿Desea quitar este panel?
TEXT
)) as $line) {
    [$english, $spanish] = explode('=', $line, 2);
    $translations[$english] = $spanish;
    $translations[$english . ':'] = $spanish . ':';
}

function translateSpanish(string $source, array $translations): string
{
    $output = '';
    $previous = null;
    foreach (token_get_all($source) as $token) {
        $text = is_array($token) ? $token[1] : $token;
        if (is_array($token) && $token[0] === T_CONSTANT_ENCAPSED_STRING
            && in_array($previous, ['=>', '='], true) && $text[0] === "'") {
            $value = str_replace(["\\'", '\\\\'], ["'", '\\'], substr($text, 1, -1));
            if (isset($translations[$value])) {
                $text = var_export($translations[$value], true);
            }
        }
        $output .= $text;
        if (!is_array($token) || !in_array($token[0], [T_WHITESPACE, T_COMMENT, T_DOC_COMMENT], true)) {
            $previous = $text;
        }
    }
    return $output;
}

if (($argv[1] ?? '') === '--check') {
    $source = "<?php /* Save */ \$a=['Save'=>'Save','x'=>'Save Changes','y'=>'Unknown %s']; \$a['Cancel']='Cancel';";
    $expected = "<?php /* Save */ \$a=['Save'=>'Guardar','x'=>'Guardar cambios','y'=>'Unknown %s']; \$a['Cancel']='Cancelar';";
    if (translateSpanish($source, $translations) !== $expected
        || translateSpanish($expected, $translations) !== $expected) {
        throw new RuntimeException('Translation check failed');
    }
    echo "Translation check passed: values translated; keys, comments and placeholders preserved; idempotent.\n";
    exit;
}

$root = $argv[1] ?? '/var/www/html/public/legacy';
$count = 0;
foreach (['include', 'modules', 'install'] as $directory) {
    $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root . '/' . $directory, FilesystemIterator::SKIP_DOTS));
    foreach ($files as $file) {
        if ($file->getFilename() !== 'es_MX.lang.php') continue;
        $source = file_get_contents($file->getPathname());
        if ($source === false) throw new RuntimeException('Cannot read ' . $file);
        $translated = translateSpanish($source, $translations);
        // The official pack has an incorrect Spanish value and missing navigation labels.
        if ($file->getPathname() === $root . '/include/language/es_MX.lang.php'
            && !str_contains($translated, '// Kits & Vet navigation es')) {
            $translated .= "\n// Kits & Vet navigation es\n"
                . "\$app_strings['LBL_QUICK_CREATE'] = 'Creación rápida';\n"
                . "\$app_strings['LBL_LAST_VIEWED'] = 'Vistos recientemente';\n"
                . "\$app_strings['LBL_LAST_VIEWED_NO_RESULT'] = 'Sin elementos vistos recientemente';\n";
        }
        if ($source !== $translated) {
            if (file_put_contents($file->getPathname(), $translated) === false) {
                throw new RuntimeException('Cannot write ' . $file);
            }
            $count++;
        }
    }
}
echo "Translated files: $count\n";

// SuiteCRM 8 ships these accessibility labels and footer text outside language packs.
$static = [];
foreach (['Quick Create', 'Recently Viewed', 'Search', 'Username', 'Password', 'Language',
          'First page', 'Previous page', 'Next page', 'Last page',
          'Navigate to first page', 'Navigate to last page', 'Select Action Menu'] as $label) {
    $spanish = $translations[$label] ?? $translations[ucwords($label)] ?? null;
    if ($spanish === null) throw new RuntimeException('Missing translation: ' . $label);
    $static['"aria-label","' . $label . '"'] = '"aria-label","' . $spanish . '"';
}
$dist = dirname($root) . '/dist';
foreach (glob($dist . '/*.js') as $file) {
    $source = file_get_contents($file);
    if ($source === false) throw new RuntimeException('Cannot read ' . $file);
    $translated = str_replace(array_keys($static), array_values($static), $source);
    $translated = str_replace('Back To Top', 'Volver arriba', $translated);
    if ($translated !== $source && file_put_contents($file, $translated) === false) {
        throw new RuntimeException('Cannot write ' . $file);
    }
}
