-- COE Quirófano v2 — esquema (prefijo qx_). Aditivo: no modifica tablas existentes.
-- Proyecto Supabase: coe-quirofano (ckjkdenwqicdjvodflba)

create table if not exists qx_sedes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activa boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists qx_ubicaciones (
  id uuid primary key default gen_random_uuid(),
  sede_id uuid not null references qx_sedes(id),
  nombre text not null,
  tipo text not null default 'sala' check (tipo in ('sala','almacen')),
  activa boolean not null default true,
  orden int default 0,
  created_at timestamptz default now()
);

create table if not exists qx_especialidades (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  activa boolean not null default true
);

create table if not exists qx_usuarios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  usuario text not null unique,
  password_hash text not null,
  pin_hash text not null,
  rol text not null check (rol in ('director','direccion','enfermeria','contabilidad')),
  sedes jsonb default '[]'::jsonb,
  activo boolean not null default true,
  debe_cambiar boolean not null default true,
  intentos_fallidos int not null default 0,
  bloqueado_hasta timestamptz,
  created_at timestamptz default now()
);

create table if not exists qx_materiales (
  id uuid primary key default gen_random_uuid(),
  codigo text,
  codigo_barras text,
  nombre text not null,
  categoria text default 'General',
  unidad text default 'pza',
  especialidad_id uuid references qx_especialidades(id),
  critico boolean not null default false,      -- material crítico (sin él no se opera)
  stock_minimo numeric not null default 0,     -- amarillo
  stock_critico numeric not null default 0,    -- rojo
  stock_maximo numeric,                        -- sugerencia de pedido
  proveedor_id uuid references fin_entidades(id) on delete set null,
  costo numeric default 0,
  controla_caducidad boolean not null default true,
  activo boolean not null default true,
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists qx_lotes (
  id uuid primary key default gen_random_uuid(),
  material_id uuid not null references qx_materiales(id) on delete cascade,
  ubicacion_id uuid not null references qx_ubicaciones(id),
  lote text,
  caducidad date,
  cantidad numeric not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists qx_lotes_mat on qx_lotes(material_id);

create table if not exists qx_lio_unidades (
  id uuid primary key default gen_random_uuid(),
  catalogo_id uuid references qui_lio_catalogo(id) on delete set null,
  marca text,
  modelo text not null,
  tipo text,                 -- monofocal, tórico, multifocal, EDOF, ACIOL, etc.
  dioptria numeric,
  cilindro numeric,
  eje int,
  adicion numeric,
  serie text,
  lote text,
  caducidad date,
  propiedad text not null default 'propio' check (propiedad in ('propio','consignacion')),
  proveedor_id uuid references fin_entidades(id) on delete set null,
  ubicacion_id uuid references qx_ubicaciones(id),
  estado text not null default 'disponible'
    check (estado in ('disponible','reservado','implantado','devuelto','caducado','merma')),
  cirugia_id uuid,
  paciente_nombre text,
  costo numeric default 0,
  pedido_especial boolean default false,
  recibido_at timestamptz default now(),
  recibido_por uuid,
  implantado_at timestamptz,
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists qx_paquetes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  especialidad_id uuid references qx_especialidades(id),
  procedimiento text,
  requiere_lio boolean not null default false,
  activo boolean not null default true,
  notas text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists qx_paquete_items (
  id uuid primary key default gen_random_uuid(),
  paquete_id uuid not null references qx_paquetes(id) on delete cascade,
  material_id uuid not null references qx_materiales(id),
  cantidad numeric not null default 1
);

create table if not exists qx_cirugias (
  id uuid primary key default gen_random_uuid(),
  folio text,
  sede_id uuid references qx_sedes(id),
  sala_id uuid references qx_ubicaciones(id),
  fecha date not null,
  hora time not null,
  duracion_min int default 60,
  especialidad_id uuid references qx_especialidades(id),
  procedimiento text,
  ojo text,
  cirujano text,
  anestesia text,
  paciente_nombre text not null,
  expediente text,
  telefono text,
  cotizacion_id text,          -- id en cotizaciones / cotizaciones_s2 (sin FK para no tocar Cotizaciones)
  cotizacion_tabla text,
  paquete_id uuid references qx_paquetes(id),
  paquete_nombre text,
  lio_unidad_id uuid references qx_lio_unidades(id),
  lio_requerido jsonb,         -- {modelo,tipo,dioptria,cilindro,eje,adicion}
  estado text not null default 'programada'
    check (estado in ('programada','confirmada','en_curso','realizada','cancelada')),
  consumo_cerrado boolean not null default false,
  cerrado_por uuid,
  cerrado_at timestamptz,
  notas text,
  creado_por uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists qx_cirugias_fecha on qx_cirugias(fecha);

create table if not exists qx_cirugia_items (
  id uuid primary key default gen_random_uuid(),
  cirugia_id uuid not null references qx_cirugias(id) on delete cascade,
  material_id uuid not null references qx_materiales(id),
  cantidad_plan numeric not null default 0,
  cantidad_usada numeric,
  es_extra boolean not null default false
);

create table if not exists qx_movimientos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('entrada','consumo','ajuste','traspaso_sal','traspaso_ent','merma','lio')),
  material_id uuid references qx_materiales(id),
  lote_id uuid references qx_lotes(id) on delete set null,
  lio_unidad_id uuid references qx_lio_unidades(id),
  ubicacion_id uuid references qx_ubicaciones(id),
  cantidad numeric not null default 0,
  cirugia_id uuid references qx_cirugias(id) on delete set null,
  conteo_id uuid,
  usuario_id uuid,
  usuario_nombre text,
  nota text,
  created_at timestamptz default now()
);
create index if not exists qx_mov_mat on qx_movimientos(material_id, created_at);

create table if not exists qx_conteos (
  id uuid primary key default gen_random_uuid(),
  ubicacion_id uuid not null references qx_ubicaciones(id),
  tipo text not null check (tipo in ('criticos','completo')),
  estado text not null default 'abierto' check (estado in ('abierto','enviado','aprobado','rechazado')),
  creado_por uuid, creado_nombre text,
  enviado_at timestamptz,
  aprobado_por uuid, aprobado_nombre text, aprobado_at timestamptz,
  notas text,
  created_at timestamptz default now()
);

create table if not exists qx_conteo_items (
  id uuid primary key default gen_random_uuid(),
  conteo_id uuid not null references qx_conteos(id) on delete cascade,
  material_id uuid references qx_materiales(id),
  lio_unidad_id uuid references qx_lio_unidades(id),
  esperado numeric,
  contado numeric,
  nota text
);

create table if not exists qx_tanques (
  id uuid primary key default gen_random_uuid(),
  sede_id uuid references qx_sedes(id),
  ubicacion_id uuid references qx_ubicaciones(id),
  nombre text not null,
  gas text not null,
  unidad text not null default 'psi',
  presion_max numeric default 2200,
  presion_alerta numeric default 800,
  presion_critica numeric default 500,
  activo boolean not null default true,
  created_at timestamptz default now()
);

create table if not exists qx_lecturas_tanque (
  id uuid primary key default gen_random_uuid(),
  tanque_id uuid not null references qx_tanques(id) on delete cascade,
  presion numeric not null,
  foto_url text,
  usuario_id uuid, usuario_nombre text,
  nota text,
  created_at timestamptz default now()
);

create table if not exists qx_config (
  clave text primary key,
  valor text,
  updated_at timestamptz default now()
);

create table if not exists qx_log (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid, usuario_nombre text,
  accion text, tabla text, registro_id text,
  detalle jsonb,
  created_at timestamptz default now()
);

-- RLS con políticas abiertas (mismo esquema que el resto de las apps del COE)
do $$ declare t text; begin
  foreach t in array array['qx_sedes','qx_ubicaciones','qx_especialidades','qx_usuarios','qx_materiales','qx_lotes',
    'qx_lio_unidades','qx_paquetes','qx_paquete_items','qx_cirugias','qx_cirugia_items','qx_movimientos','qx_conteos',
    'qx_conteo_items','qx_tanques','qx_lecturas_tanque','qx_config','qx_log'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t||'_all', t);
    execute format('create policy %I on %I for all to public using (true) with check (true)', t||'_all', t);
  end loop;
end $$;

-- Storage para fotos de manómetros y logo
insert into storage.buckets (id, name, public) values ('qx-fotos','qx-fotos',true) on conflict (id) do nothing;
drop policy if exists qx_fotos_rw on storage.objects;
create policy qx_fotos_rw on storage.objects for all to public using (bucket_id='qx-fotos') with check (bucket_id='qx-fotos');

-- Datos iniciales
insert into qx_sedes(nombre) values ('Tacámbaro'),('Morelia') on conflict do nothing;
insert into qx_ubicaciones(sede_id,nombre,tipo,orden)
select s.id, x.n, x.t, x.o from qx_sedes s,
  (values ('Quirófano 1','sala',1),('Quirófano 2','sala',2),('Almacén de quirófano','almacen',0)) x(n,t,o)
where s.nombre='Tacámbaro'
  and not exists (select 1 from qx_ubicaciones u where u.sede_id=s.id and u.nombre=x.n);
insert into qx_especialidades(nombre) values ('Oftalmología'),('Otorrinolaringología'),('Cirugía vascular')
on conflict do nothing;
insert into qx_config(clave,valor) values ('dias_proyeccion','14'),('folio_cirugia','0') on conflict do nothing;

-- Usuario inicial: director / coe2026 / PIN 0000 (obliga a cambiar al primer ingreso)
insert into qx_usuarios(nombre,usuario,password_hash,pin_hash,rol,debe_cambiar)
select 'Dr. José Antonio Villegas Ávila','director',
  encode(extensions.digest('qx|director|coe2026','sha256'),'hex'),
  encode(extensions.digest('qxpin|director|0000','sha256'),'hex'),
  'director', true
where not exists (select 1 from qx_usuarios where usuario='director');

-- Tiempo real (actualización automática entre iPads)
do $$ declare t text; begin
  foreach t in array array['qx_cirugias','qx_cirugia_items','qx_lotes','qx_lio_unidades','qx_lecturas_tanque','qx_conteos','qx_materiales','qx_paquetes'] loop
    begin execute format('alter publication supabase_realtime add table %I', t);
    exception when others then null; end;
  end loop;
end $$;

-- ============================================================
-- v2.1 — Candados de programación: pago, seguridad, LIO verificado
-- (aditivo: se puede correr junto con lo anterior o después)
-- ============================================================
alter table qx_cirugias add column if not exists costo_total numeric default 0;
alter table qx_cirugias add column if not exists fecha_nacimiento date;
alter table qx_cirugias add column if not exists alergias text;
alter table qx_cirugias add column if not exists anticoagulantes text;
alter table qx_cirugias add column if not exists checklist jsonb default '{}'::jsonb;   -- preoperatorio
alter table qx_cirugias add column if not exists timeout jsonb;                       -- pausa de seguridad en sala
alter table qx_cirugias add column if not exists lio_verificado_por uuid;
alter table qx_cirugias add column if not exists lio_verificado_nombre text;
alter table qx_cirugias add column if not exists lio_verificado_at timestamptz;
alter table qx_cirugias add column if not exists sin_anticipo_autorizado_por text;  -- excepción del Director
alter table qx_cirugias add column if not exists sin_anticipo_motivo text;

create table if not exists qx_cirugia_evidencias (
  id uuid primary key default gen_random_uuid(),
  cirugia_id uuid not null references qx_cirugias(id) on delete cascade,
  tipo text not null check (tipo in ('anticipo','abono','liquidacion','reembolso','consentimiento','biometria','valoracion','otro')),
  monto numeric default 0,
  metodo text,                 -- efectivo, tarjeta, transferencia, cortesía
  folio text,                  -- folio de venta eOptics / referencia
  url text,                    -- foto o PDF
  nota text,
  usuario_id uuid, usuario_nombre text,
  validado_por text, validado_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists qx_evid_cx on qx_cirugia_evidencias(cirugia_id);
alter table qx_cirugia_evidencias enable row level security;
drop policy if exists qx_cirugia_evidencias_all on qx_cirugia_evidencias;
create policy qx_cirugia_evidencias_all on qx_cirugia_evidencias for all to public using (true) with check (true);
do $$ begin
  begin execute 'alter publication supabase_realtime add table qx_cirugia_evidencias'; exception when others then null; end;
end $$;

insert into qx_config(clave,valor) values
  ('anticipo_minimo_monto','1000'),     -- monto mínimo de anticipo para programar
  ('anticipo_minimo_pct','0'),          -- o % del costo total (se usa el mayor)
  ('dias_liquidar_antes','1')           -- días antes de la cirugía en que debe estar liquidada
on conflict do nothing;

-- ============================================================
-- v2.2 — LIO de respaldo, validación de pagos, mensajes al paciente,
--        seguimiento posoperatorio y reporte semanal
-- ============================================================
alter table qx_cirugias add column if not exists lio_respaldo_id uuid references qx_lio_unidades(id);
alter table qx_cirugias add column if not exists riesgo_diabetes boolean default false;
alter table qx_cirugias add column if not exists riesgo_glaucoma boolean default false;
alter table qx_cirugias add column if not exists cita_subsecuente timestamptz;
alter table qx_cirugias add column if not exists cancel_motivo text;
alter table qx_cirugias add column if not exists lio_implantado_id uuid;

create table if not exists qx_mensajes (
  id uuid primary key default gen_random_uuid(),
  cirugia_id uuid not null references qx_cirugias(id) on delete cascade,
  tipo text not null check (tipo in ('recordatorio_48h','seguimiento_d3','cita_subsecuente','control_largo')),
  programado_para date not null,
  prioridad boolean not null default false,
  token text not null unique default md5(random()::text || clock_timestamp()::text),
  paciente_nombre text, telefono text, ojo text, procedimiento text, fecha_cirugia date, sede_id uuid,
  estado text not null default 'pendiente' check (estado in ('pendiente','enviado','respondido','cancelado')),
  enviado_at timestamptz, enviado_por text,
  respuesta jsonb,                 -- {ojo_rojo, lagana, vision, comentario, at, via}
  alarma boolean not null default false,
  atendido_por text, atendido_at timestamptz, atendido_nota text,
  created_at timestamptz default now(),
  unique (cirugia_id, tipo)
);
create index if not exists qx_msj_prog on qx_mensajes(programado_para, estado);
alter table qx_mensajes enable row level security;
drop policy if exists qx_mensajes_all on qx_mensajes;
create policy qx_mensajes_all on qx_mensajes for all to public using (true) with check (true);
do $$ begin
  begin execute 'alter publication supabase_realtime add table qx_mensajes'; exception when others then null; end;
end $$;

insert into qx_config(clave,valor) values
  ('whatsapp_clinica','4591345529'),
  ('tel_clinica','(459) 100 0431'),
  ('meses_control_riesgo','4'),   -- diabetes o glaucoma
  ('meses_control','6')
on conflict do nothing;

-- ============================================================
-- v2.3 — Cotizaciones de consultorio (cirugía oftalmología / otorrino,
--        láser y estudios), catálogo de precios con vigencias
-- ============================================================
alter table qx_usuarios drop constraint if exists qx_usuarios_rol_check;
alter table qx_usuarios add constraint qx_usuarios_rol_check
  check (rol in ('director','direccion','enfermeria','contabilidad','consultorio'));

create table if not exists qx_precios (
  id uuid primary key default gen_random_uuid(),
  categoria text not null check (categoria in ('cirugia','laser','estudio','lio')),
  especialidad_id uuid references qx_especialidades(id),
  nombre text not null,
  codigo text,
  lateralidad text not null default 'por_ojo' check (lateralidad in ('por_ojo','ambos_ojos','sin_lado')),
  precio numeric not null default 0,           -- por ojo, por ambos ojos o por procedimiento (según lateralidad)
  precio_bilateral numeric,                    -- opcional: precio especial si se cotizan los dos ojos
  requiere_lio boolean not null default false,
  paquete_id uuid references qx_paquetes(id),
  incluye text,
  vigente_desde date default current_date,
  vigente_hasta date,
  permite_descuento boolean not null default false,
  desc_max_pct numeric not null default 0,     -- descuento sin autorización de Dirección
  activo boolean not null default true,
  orden int default 0,
  updated_at timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists qx_cotizaciones (
  id uuid primary key default gen_random_uuid(),
  folio text not null,
  token text not null unique,
  sede_id uuid references qx_sedes(id),
  paciente_nombre text not null,
  expediente text,
  telefono1 text not null,
  telefono2 text,
  motivo text,                                  -- motivo del estudio / diagnóstico
  medico text,
  items jsonb not null default '[]'::jsonb,     -- copia de precios al momento de cotizar
  subtotal numeric default 0,
  descuento numeric default 0,
  descuento_motivo text,
  descuento_autorizado_por text,
  total numeric default 0,
  anticipo numeric default 0,
  vigencia_hasta date not null,
  estado text not null default 'vigente' check (estado in ('vigente','programada','realizada','cancelada')),
  cirugia_ids jsonb default '[]'::jsonb,
  notas text,
  elaboro text,
  elaboro_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists qx_cot_creado on qx_cotizaciones(created_at);

do $$ declare t text; begin
  foreach t in array array['qx_precios','qx_cotizaciones'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t||'_all', t);
    execute format('create policy %I on %I for all to public using (true) with check (true)', t||'_all', t);
    begin execute format('alter publication supabase_realtime add table %I', t); exception when others then null; end;
  end loop;
end $$;

insert into qx_config(clave,valor) values ('vig_cirugia','30'),('vig_laser','30'),('vig_estudio','15') on conflict do nothing;

-- Catálogo inicial SIN precio: Dirección captura precios y vigencias en Más → Precios y vigencias
insert into qx_precios(categoria,especialidad_id,nombre,lateralidad,requiere_lio,orden)
select x.cat,(select id from qx_especialidades where nombre=x.esp),x.nom,x.lat,x.lio,x.ord
from (values
 ('cirugia','Oftalmología','Facoemulsificación con LIO','por_ojo',true,1),
 ('cirugia','Oftalmología','Pterigión con autoinjerto','por_ojo',false,2),
 ('cirugia','Oftalmología','Trabeculectomía','por_ojo',false,3),
 ('cirugia','Oftalmología','Vitrectomía posterior','por_ojo',false,4),
 ('cirugia','Oftalmología','Inyección intravítrea','por_ojo',false,5),
 ('cirugia','Oftalmología','Blefaroplastia superior','ambos_ojos',false,6),
 ('cirugia','Oftalmología','Chalazión','por_ojo',false,7),
 ('cirugia','Otorrinolaringología','Septoplastia','sin_lado',false,20),
 ('cirugia','Otorrinolaringología','Septorrinoplastia','sin_lado',false,21),
 ('cirugia','Otorrinolaringología','Amigdalectomía','sin_lado',false,22),
 ('cirugia','Otorrinolaringología','Cirugía endoscópica de senos paranasales','sin_lado',false,23),
 ('laser','Oftalmología','Capsulotomía YAG','por_ojo',false,1),
 ('laser','Oftalmología','Iridotomía YAG','por_ojo',false,2),
 ('laser','Oftalmología','Panfotocoagulación (por sesión)','por_ojo',false,3),
 ('laser','Oftalmología','Láser focal / rejilla macular','por_ojo',false,4),
 ('laser','Oftalmología','Trabeculoplastia SLT','por_ojo',false,5),
 ('estudio','Oftalmología','OCT macular','ambos_ojos',false,1),
 ('estudio','Oftalmología','OCT de nervio óptico','ambos_ojos',false,2),
 ('estudio','Oftalmología','Campimetría','ambos_ojos',false,3),
 ('estudio','Oftalmología','Topografía corneal','ambos_ojos',false,4),
 ('estudio','Oftalmología','Biometría óptica','ambos_ojos',false,5),
 ('estudio','Oftalmología','Paquimetría','ambos_ojos',false,6),
 ('estudio','Oftalmología','Ultrasonido modo B','por_ojo',false,7),
 ('estudio','Oftalmología','Microscopía especular','ambos_ojos',false,8),
 ('estudio','Oftalmología','Fotografía de fondo de ojo','ambos_ojos',false,9),
 ('lio','Oftalmología','LIO monofocal','por_ojo',false,1),
 ('lio','Oftalmología','LIO tórico','por_ojo',false,2),
 ('lio','Oftalmología','LIO multifocal','por_ojo',false,3),
 ('lio','Oftalmología','LIO multifocal tórico','por_ojo',false,4),
 ('lio','Oftalmología','LIO EDOF (foco extendido)','por_ojo',false,5)
) as x(cat,esp,nom,lat,lio,ord)
where not exists (select 1 from qx_precios p where p.nombre=x.nom);

-- ============================================================
-- v2.4 — Criticidad en 3 niveles, paquetes de estudios,
--        programa de inventarios sin prórroga con escalamiento a Finanzas
-- ============================================================
alter table qx_materiales add column if not exists criticidad text not null default 'no_critico';
alter table qx_materiales drop constraint if exists qx_materiales_criticidad_check;
alter table qx_materiales add constraint qx_materiales_criticidad_check check (criticidad in ('critico','moderado','no_critico'));
update qx_materiales set criticidad='critico' where critico and criticidad='no_critico';

alter table qx_precios add column if not exists es_paquete boolean not null default false;
alter table qx_precios add column if not exists componentes jsonb default '[]'::jsonb;   -- nombres de estudios incluidos

create table if not exists qx_escalamientos (
  id uuid primary key default gen_random_uuid(),
  clave text not null unique,               -- p. ej. INV-completo-2026-10-19-<sede>
  tipo text not null,                       -- inventario_completo, inventario_criticos
  sede_id uuid references qx_sedes(id),
  fecha_programada date not null,
  detalle text,
  fin_tarea_clave text,
  resuelto_at timestamptz,
  created_at timestamptz default now()
);
alter table qx_escalamientos enable row level security;
drop policy if exists qx_escalamientos_all on qx_escalamientos;
create policy qx_escalamientos_all on qx_escalamientos for all to public using (true) with check (true);

insert into qx_config(clave,valor) values
  ('inv_base','2026-10-05'),          -- fecha ancla del programa (último inventario completo realizado)
  ('freq_completo','15'),('freq_criticos','7'),
  ('tels_programar','(459) 100 0431|(459) 134 5529'),('qr_destino','whatsapp')
on conflict do nothing;

insert into qx_precios(categoria,especialidad_id,nombre,lateralidad,es_paquete,componentes,orden)
select 'estudio',(select id from qx_especialidades where nombre='Oftalmología'),x.nom,'ambos_ojos',true,x.comp::jsonb,x.ord
from (values
 ('Paquete glaucoma: OCT de nervio óptico + campimetría','["OCT de nervio óptico","Campimetría"]',0),
 ('Paquete glaucoma completo: OCT nervio + campimetría + paquimetría','["OCT de nervio óptico","Campimetría","Paquimetría"]',0),
 ('Paquete retina: OCT macular + fotografía de fondo de ojo','["OCT macular","Fotografía de fondo de ojo"]',0),
 ('Paquete preoperatorio de catarata: biometría + topografía + microscopía especular','["Biometría óptica","Topografía corneal","Microscopía especular"]',0)
) as x(nom,comp,ord)
where not exists (select 1 from qx_precios p where p.nombre=x.nom);

-- ============================================================
-- v2.5 · Carro rojo, criticidad en 2 grupos, conteo con evidencia,
--        accesos por usuario y cotización obligatoria para programar
-- ============================================================
alter table qx_ubicaciones drop constraint if exists qx_ubicaciones_tipo_check;
alter table qx_ubicaciones add constraint qx_ubicaciones_tipo_check check (tipo in ('sala','almacen','carro'));

alter table qx_materiales add column if not exists area text not null default 'quirofano';      -- quirofano | carro_rojo
alter table qx_materiales add column if not exists gaveta text;                                 -- orden físico para contar
alter table qx_materiales add column if not exists pzas_presentacion numeric not null default 1; -- piezas por caja
alter table qx_materiales add column if not exists precio_paciente numeric;
create unique index if not exists qx_materiales_codigo_uk on qx_materiales(codigo) where codigo is not null;
-- dos grupos: crítico / no crítico (lo "moderado" pasa a no crítico)
alter table qx_materiales drop constraint if exists qx_materiales_criticidad_check;
update qx_materiales set criticidad='no_critico' where criticidad='moderado';
alter table qx_materiales add constraint qx_materiales_criticidad_check check (criticidad in ('critico','no_critico'));

alter table qx_usuarios add column if not exists modulos jsonb;   -- null = los del perfil
alter table qx_usuarios add column if not exists permisos jsonb;  -- null = los del perfil

alter table qx_conteos drop constraint if exists qx_conteos_tipo_check;
alter table qx_conteos add constraint qx_conteos_tipo_check check (tipo in ('criticos','completo','carro'));
alter table qx_conteos drop constraint if exists qx_conteos_estado_check;
alter table qx_conteos add constraint qx_conteos_estado_check check (estado in ('abierto','reconteo','enviado','aprobado','rechazado'));
alter table qx_conteos add column if not exists fotos jsonb default '[]'::jsonb;
alter table qx_conteos add column if not exists reconteo_por uuid;
alter table qx_conteos add column if not exists reconteo_nombre text;
alter table qx_conteos add column if not exists reconteo_at timestamptz;
alter table qx_conteos add column if not exists precision int;
alter table qx_conteo_items add column if not exists cajas numeric;
alter table qx_conteo_items add column if not exists sueltas numeric;
alter table qx_conteo_items add column if not exists contado2 numeric;
alter table qx_conteo_items add column if not exists contado2_por text;

alter table qx_cirugias add column if not exists sin_cotizacion_autorizado_por text;
alter table qx_cirugias add column if not exists sin_cotizacion_motivo text;

create table if not exists qx_carro_revisiones (
  id uuid primary key default gen_random_uuid(),
  sede_id uuid references qx_sedes(id),
  tipo text not null check (tipo in ('rapida','completa','reposicion','uso')),
  sello_anterior text, sello_nuevo text,
  checks jsonb, faltantes int, vencidos int,
  evento text, paciente text, cirugia_id uuid, items jsonb,
  notas text, usuario_id uuid, usuario_nombre text,
  created_at timestamptz default now()
);
alter table qx_carro_revisiones enable row level security;
drop policy if exists qx_carro_revisiones_all on qx_carro_revisiones;
create policy qx_carro_revisiones_all on qx_carro_revisiones for all to public using (true) with check (true);
do $$ begin
  begin execute 'alter publication supabase_realtime add table qx_carro_revisiones'; exception when others then null; end;
end $$;

insert into qx_config(clave,valor) values
  ('carro_aviso_dias','180'),   -- cambio preventivo: 6 meses antes de caducar
  ('carro_rev_dias','7'),       -- revisión de sello y equipo
  ('conteo_foto','1')           -- foto de gaveta obligatoria al cerrar conteo
on conflict do nothing;

-- ============================================================
-- v2.5 · CATÁLOGO REAL COE (formatos del 05/10/2026 y carro rojo)
-- Idempotente: solo inserta lo que no existe (por código).
-- ============================================================
insert into qx_ubicaciones(sede_id,nombre,tipo,orden)
select s.id,'Carro rojo','carro',9 from qx_sedes s where s.nombre like 'Tac%'
and not exists (select 1 from qx_ubicaciones u where u.sede_id=s.id and u.tipo='carro');
insert into qx_materiales(codigo,nombre,categoria,unidad,criticidad,critico,stock_minimo,stock_critico,pzas_presentacion,area,gaveta,notas,costo) values
('QX-001','Viscoelástico de alta densidad (Viscoat)','Red fría','pza','critico',true,1,0,1,'quirofano','Refrigerador',null,0),
('QX-002','Viscoelástico de baja densidad (Amvisc)','Red fría','pza','critico',true,5,2,1,'quirofano','Refrigerador','caducidad escrita "29/05": verificar',0),
('QX-003','Antiangiogénico','Red fría','pza','critico',true,1,0,1,'quirofano','Refrigerador','existencia escrita "1 ml"',0),
('QX-004','Toxina botulínica','Red fría','frasco','no_critico',false,0,0,1,'quirofano','Refrigerador',null,0),
('QX-005','Mitomicina','Fármacos y colirios','frasco','critico',true,5,2,1,'quirofano','Fármacos','tenía caducidad 02/28 sin existencia escrita',0),
('QX-006','Manitol 20 g','Fármacos y colirios','frasco','no_critico',false,0,0,1,'quirofano','Fármacos','existencia ilegible ("8" o "0")',0),
('QX-007','Captopril','Fármacos y colirios','tableta','no_critico',false,0,0,1,'quirofano','Fármacos','existencia ilegible',0),
('QX-008','Miochol (acetilcolina)','Fármacos y colirios','frasco','critico',true,2,1,1,'quirofano','Fármacos',null,0),
('QX-009','Lidocaína simple','Fármacos y colirios','frasco','critico',true,2,1,1,'quirofano','Fármacos',null,0),
('QX-010','Lidocaína sin conservador','Fármacos y colirios','ampolleta','critico',true,10,3,10,'quirofano','Fármacos','mínimo "1 caja" (10 amp, verificar)',0),
('QX-011','Lidocaína con epinefrina 2%','Fármacos y colirios','frasco','critico',true,2,1,1,'quirofano','Fármacos',null,0),
('QX-012','Lidocaína ungüento','Fármacos y colirios','tubo','no_critico',false,0,0,1,'quirofano','Fármacos',null,0),
('QX-013','Pisacaína 2% (lidocaína)','Fármacos y colirios','frasco','critico',true,0,0,1,'quirofano','Fármacos',null,0),
('QX-014','TP (tropicamida/fenilefrina) colirio','Fármacos y colirios','frasco','critico',true,6,2,1,'quirofano','Fármacos',null,0),
('QX-015','Vigamoxi (moxifloxacino) colirio','Fármacos y colirios','frasco','critico',true,2,1,1,'quirofano','Fármacos',null,0),
('QX-016','Ponti (tetracaína) colirio','Fármacos y colirios','frasco','critico',true,6,2,1,'quirofano','Fármacos',null,0),
('QX-017','Collifrin infantil','Fármacos y colirios','frasco','no_critico',false,0,0,1,'quirofano','Fármacos',null,0),
('QX-018','Triamcinolona','Fármacos y colirios','frasco','no_critico',false,0,0,1,'quirofano','Fármacos',null,0),
('QX-019','Nortenz','Fármacos y colirios','pza','no_critico',false,0,0,1,'quirofano','Fármacos',null,0),
('QX-020','Bupivacaína','Fármacos y colirios','frasco','critico',true,0,0,1,'quirofano','Fármacos',null,0),
('QX-021','Azul tripano','Insumos oftalmológicos','ampolleta','critico',true,2,1,1,'quirofano','Oftalmo A',null,0),
('QX-022','Camisa de faco','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo A',null,0),
('QX-023','Vitrector (continuous flow cutter)','Insumos oftalmológicos','pza','critico',true,2,1,1,'quirofano','Oftalmo A','tenía caducidad 08/28 sin existencia escrita',0),
('QX-024','Cassette de faco estéril','Insumos oftalmológicos','pza','critico',true,2,1,1,'quirofano','Oftalmo A',null,0),
('QX-025','Gancho pupilar','Insumos oftalmológicos','pza','critico',true,2,1,1,'quirofano','Oftalmo A',null,0),
('QX-026','Cuchillete 15°','Insumos oftalmológicos','pza','critico',true,10,3,1,'quirofano','Oftalmo B',null,0),
('QX-027','Cuchillete 2.2 mm','Insumos oftalmológicos','pza','critico',true,10,3,1,'quirofano','Oftalmo B','medida escrita "2,?°": verificar',0),
('QX-028','Cuchillete 2.5 mm crescent','Insumos oftalmológicos','pza','critico',true,6,2,6,'quirofano','Oftalmo B','mínimo "1 caja" (6 pzas, verificar)',0),
('QX-029','Cuchillete 2.75 mm','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo B',null,0),
('QX-030','Cuchillete 2.8 mm','Insumos oftalmológicos','pza','critico',true,10,3,1,'quirofano','Oftalmo B',null,0),
('QX-031','Cuchillete 3.0 mm','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo B','agregado a mano en el formato',0),
('QX-032','Anillo de tensión capsular 12 mm','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-033','Anillo de tensión capsular 13 mm','Insumos oftalmológicos','pza','critico',true,2,1,1,'quirofano','Oftalmo C',null,0),
('QX-034','Ganchos de bolsa capsular','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-035','Ganchos de iris','Insumos oftalmológicos','pza','critico',true,1,0,1,'quirofano','Oftalmo C',null,0),
('QX-036','Anillo de Malyugin','Insumos oftalmológicos','pza','critico',true,1,0,1,'quirofano','Oftalmo C',null,0),
('QX-037','Set de intubación lagrimal 27 G','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-038','Riboflavina Peschke M','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-039','Riboflavina Peschke TE','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-040','Esponjas de Merocel','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-041','Membrana amniótica','Insumos oftalmológicos','pza','critico',true,6,2,1,'quirofano','Oftalmo C',null,0),
('QX-042','Tiras de fluoresceína','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-043','Sutura 10-0 (china)','Suturas','sobre','critico',true,0,0,1,'quirofano','Suturas',null,0),
('QX-044','Sutura Prolene 6-0','Suturas','sobre','no_critico',false,0,0,1,'quirofano','Suturas',null,0),
('QX-045','Sutura Nylon 6-0','Suturas','sobre','no_critico',false,5,2,1,'quirofano','Suturas',null,0),
('QX-046','Sutura Gore-Tex','Suturas','sobre','no_critico',false,0,0,1,'quirofano','Suturas',null,0),
('QX-047','Sutura seda','Suturas','sobre','no_critico',false,0,0,1,'quirofano','Suturas',null,0),
('QX-048','Sutura Ethilon (poliamida) 10-0','Suturas','sobre','critico',true,0,0,1,'quirofano','Suturas','tenía caducidad 06/30 sin existencia',0),
('QX-049','Sutura Vicryl 6-0','Suturas','sobre','no_critico',false,0,0,1,'quirofano','Suturas',null,0),
('QX-050','Sutura Vicryl 7-0','Suturas','sobre','no_critico',false,0,0,1,'quirofano','Suturas',null,0),
('QX-051','Hisopos','Insumos oftalmológicos','pza','no_critico',false,50,15,50,'quirofano','Oftalmo C','mínimo "1 bolsa" (50 pzas, verificar)',0),
('QX-052','Cartucho de inyector de LIO Monarca','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo A',null,0),
('QX-053','Cartucho de inyector Monarca (Alcon)','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano','Oftalmo A',null,0),
('QX-054','Goniolente','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-055','Implante para evisceración','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-056','Inyector de ICL','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano','Oftalmo C',null,0),
('QX-057','Algodón','Insumos médicos','bolsa','no_critico',false,1,0,1,'quirofano','Médicos A',null,0),
('QX-058','Alcohol','Insumos médicos','pza','no_critico',false,1,0,1,'quirofano','Médicos A',null,0),
('QX-059','Alcohol puro 1 L','Insumos médicos','frasco','no_critico',false,1,0,1,'quirofano','Médicos A',null,0),
('QX-060','Agua inyectable 10 ml','Insumos médicos','ampolleta','critico',true,30,9,1,'quirofano','Médicos A',null,0),
('QX-061','Agua inyectable 1 L','Insumos médicos','frasco','no_critico',false,10,3,1,'quirofano','Médicos A',null,0),
('QX-062','Agua tridestilada','Insumos médicos','galón','no_critico',false,1,0,1,'quirofano','Médicos A',null,0),
('QX-063','Aguja de insulina','Insumos médicos','pza','no_critico',false,100,30,100,'quirofano','Médicos B','mínimo "1 caja" (100 pzas, verificar)',0),
('QX-064','Jeringa de 13 mm','Insumos médicos','pza','no_critico',false,100,30,100,'quirofano','Médicos B','mínimo "1 caja" (100 pzas, verificar)',0),
('QX-065','Jeringa de 3 ml','Insumos médicos','pza','no_critico',false,100,30,100,'quirofano','Médicos B','mínimo "1 caja" (100 pzas, verificar)',0),
('QX-066','Jeringa de 5 ml','Insumos médicos','pza','no_critico',false,100,30,100,'quirofano','Médicos B','mínimo "1 caja" (100 pzas, verificar)',0),
('QX-067','Jeringa de 10 ml','Insumos médicos','pza','no_critico',false,100,30,100,'quirofano','Médicos B','mínimo "1 caja" (100 pzas, verificar)',0),
('QX-068','Jeringa de 20 ml','Insumos médicos','pza','no_critico',false,50,15,50,'quirofano','Médicos B','mínimo "1 caja" (50 pzas, verificar)',0),
('QX-069','Jeringas desechables (anotación a mano)','Insumos médicos','pza','no_critico',false,0,0,1,'quirofano','Médicos B','renglón escrito a mano "Jeringas Desm.": verificar nombre',0),
('QX-070','Hojas de bisturí','Insumos médicos','pza','no_critico',false,2,1,1,'quirofano','Médicos B','existencia ilegible',0),
('QX-071','Puntas nasales','Insumos médicos','pza','critico',true,30,9,1,'quirofano','Médicos C',null,0),
('QX-072','Transpore','Insumos médicos','rollo','no_critico',false,12,4,12,'quirofano','Médicos C','mínimo "1 caja" (12 rollos, verificar)',0),
('QX-073','Cinta Micropore 1.3 in','Insumos médicos','rollo','no_critico',false,12,4,12,'quirofano','Médicos C','mínimo "1 caja" (12 rollos, verificar)',0),
('QX-074','Tegaderm CH','Insumos médicos','pza','no_critico',false,50,15,50,'quirofano','Médicos C','mínimo "1 caja" (50 pzas, verificar)',0),
('QX-075','Tegaderm G','Insumos médicos','pza','no_critico',false,50,15,50,'quirofano','Médicos C','mínimo "1 caja" (50 pzas, verificar)',0),
('QX-076','Krit 1 L','Insumos médicos','frasco','no_critico',false,1,0,1,'quirofano','Médicos C',null,0),
('QX-077','Normogotero / Venoset','Insumos médicos','pza','critico',true,40,12,1,'quirofano','Médicos C',null,0),
('QX-078','Germicin','Insumos médicos','frasco','no_critico',false,1,0,1,'quirofano','Médicos C',null,0),
('QX-079','Parches para monitoreo cardiaco','Insumos médicos','pza','critico',true,50,15,50,'quirofano','Médicos C','mínimo "1 bolsa" (50 pzas, verificar)',0),
('QX-080','Punzocat azul','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-081','Punzocat morado','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-082','Punzocat rosa','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-083','Punzocat rojo','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-084','Punzocat amarillo','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-085','Punzocat verde','Insumos médicos','pza','critico',true,5,2,1,'quirofano','Médicos D',null,0),
('QX-086','Cánulas','Insumos médicos','pza','no_critico',false,0,0,1,'quirofano','Médicos D',null,0),
('QX-087','Cartuchos Monarca II','Insumos médicos','pza','critico',true,0,0,1,'quirofano','Médicos D',null,0),
('QX-088','Cartuchos Monarca III','Insumos médicos','pza','critico',true,0,0,1,'quirofano','Médicos D',null,0),
('QX-089','Gasas grandes','Insumos médicos','paquete','no_critico',false,100,30,50,'quirofano','Médicos D','mínimo "2 cajas" (50 paq. por caja, verificar)',0),
('QX-090','Rollo de gasa','Insumos médicos','rollo','no_critico',false,0,0,1,'quirofano','Médicos D',null,0),
('QX-091','Tubo de conexión de oxígeno','Insumos médicos','pza','critico',true,0,0,1,'quirofano','Médicos D',null,0),
('QX-092','Marcador para piel','Insumos médicos','pza','critico',true,0,0,1,'quirofano','Médicos D','marcar el ojo a operar',0),
('QX-093','Gorros','Desechables','pza','no_critico',false,100,30,100,'quirofano','Desechables','mínimo "1 bolsa" (100 pzas, verificar)',0),
('QX-094','Turbante','Desechables','pza','no_critico',false,50,15,50,'quirofano','Desechables','mínimo "1 bolsa" (50 pzas, verificar)',0),
('QX-095','Cubrebocas paciente','Desechables','pza','no_critico',false,100,30,50,'quirofano','Desechables','mínimo "2 cajas"; la cifra 176 parece del renglón siguiente: verificar',0),
('QX-096','Cubrebocas cirujano','Desechables','pza','no_critico',false,0,0,50,'quirofano','Desechables','verificar renglón',0),
('QX-097','Botas paciente','Desechables','par','no_critico',false,0,0,1,'quirofano','Desechables','verificar renglón',0),
('QX-098','Botas cirujano','Desechables','par','no_critico',false,150,45,50,'quirofano','Desechables','mínimo "3 bolsas" (50 por bolsa, verificar)',0),
('QX-099','Bata para cirujano con toalla','Desechables','pza','critico',true,20,6,1,'quirofano','Desechables',null,0),
('QX-100','Campo oftálmico / sábana oftálmica','Desechables','pza','critico',true,40,12,1,'quirofano','Desechables',null,0),
('QX-101','Sábana para camilla','Desechables','rollo','no_critico',false,2,1,1,'quirofano','Desechables','mínimo "2 bolsas"; existencia "1 rollo"',0),
('QX-102','Funda para mesa Mayo','Desechables','pza','no_critico',false,20,6,1,'quirofano','Desechables',null,0),
('QX-103','Campos sencillos estériles 60x60','Desechables','pza','no_critico',false,10,3,1,'quirofano','Desechables',null,0),
('QX-104','Campos hendidos oftálmicos estériles','Desechables','pza','critico',true,10,3,1,'quirofano','Desechables',null,0),
('QX-105','Guantes quirúrgicos 6.5','Desechables','par','critico',true,50,15,50,'quirofano','Desechables','mínimo "1 caja" (50 pares, verificar)',0),
('QX-106','Guantes quirúrgicos 7.5','Desechables','par','critico',true,50,15,50,'quirofano','Desechables','mínimo "1 caja" (50 pares, verificar)',0),
('QX-107','Guantes individuales chicos','Desechables','pza','no_critico',false,100,30,100,'quirofano','Desechables','mínimo "1 caja" (100, verificar)',0),
('QX-108','Guantes individuales medianos','Desechables','pza','no_critico',false,0,0,100,'quirofano','Desechables','anotación a mano "Guante Ind. M."',0),
('QX-109','Bata quirúrgica sin toalla','Desechables','pza','no_critico',false,0,0,1,'quirofano','Desechables',null,0),
('QX-110','Campo desechable','Desechables','pza','no_critico',false,0,0,1,'quirofano','Desechables',null,0),
('QX-111','Campos hendidos simples','Desechables','pza','no_critico',false,0,0,1,'quirofano','Desechables',null,0),
('QX-112','Paño limpia instrumentos','Desechables','pza','no_critico',false,0,0,1,'quirofano','Desechables',null,0),
('QX-113','Solución salina balanceada 250 ml','Soluciones','frasco','critico',true,15,4,1,'quirofano','Soluciones',null,0),
('QX-114','Solución salina balanceada 500 ml','Soluciones','frasco','critico',true,15,4,1,'quirofano','Soluciones',null,0),
('QX-115','Solución cloruro de sodio 50 ml','Soluciones','frasco','no_critico',false,0,0,1,'quirofano','Soluciones',null,0),
('QX-116','Solución Hartmann 500 ml','Soluciones','bolsa','critico',true,30,9,1,'quirofano','Soluciones',null,0),
('QX-117','Kleenex','Insumos generales','caja','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-118','Repuestos Air Wick','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-119','Avagard','Insumos generales','frasco','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-120','Antibenzil','Insumos generales','frasco','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-121','Cepillo con isodine','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-122','Cepillo quirúrgico','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-123','Microdacyn','Insumos generales','frasco','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-124','Cal sodada','Insumos generales','pza','critico',true,0,0,1,'quirofano','Generales','máquina de anestesia',0),
('QX-125','Jabón Gojo','Insumos generales','frasco','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-126','Formol','Insumos generales','frasco','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-127','Amprolene / Biolene','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-128','Cinta para esterilizar mediante gas','Insumos generales','rollo','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-129','Ligas','Insumos generales','bolsa','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-130','Bolsas autosellables 7x26 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-131','Bolsas autosellables 19x36 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-132','Bolsas autosellables 10x13.5 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-133','Bolsas autosellables 30x38 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales',null,0),
('QX-134','Bolsas autosellables 7.5x28 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales','caducidad escrita "20/20": verificar',0),
('QX-135','Bolsas autosellables 5.7x13 cm','Insumos generales','pza','no_critico',false,0,0,1,'quirofano','Generales','anotado sobre "carbón activado"',0),
('QX-136','Bolsas estériles chicas (reesterilizado)','Material reesterilizado','pza','no_critico',false,0,0,1,'quirofano','Reesterilizado','fecha de reesterilización por lote',0),
('QX-137','Bolsas estériles grandes (reesterilizado)','Material reesterilizado','pza','no_critico',false,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-138','Cassette faco (reesterilizado)','Material reesterilizado','pza','critico',true,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-139','Cepillos (reesterilizado)','Material reesterilizado','pza','no_critico',false,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-140','Campo simple (reesterilizado)','Material reesterilizado','pza','no_critico',false,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-141','Bata (reesterilizado)','Material reesterilizado','pza','no_critico',false,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-142','Vitrector (reesterilizado)','Material reesterilizado','pza','critico',true,0,0,1,'quirofano','Reesterilizado',null,0),
('QX-143','Iodopovidona 5% oftálmica (antisepsia)','Fármacos y colirios','frasco','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). profilaxis de endoftalmitis',0),
('QX-144','Iodopovidona 10% para piel','Insumos médicos','frasco','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-145','Cefuroxima o moxifloxacino intracameral','Fármacos y colirios','ampolleta','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). antibiótico intracameral al final de faco',0),
('QX-146','Epinefrina intracameral sin conservador','Fármacos y colirios','ampolleta','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). midriasis intraoperatoria',0),
('QX-147','Carbacol (Miostat)','Fármacos y colirios','frasco','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-148','Viscoelástico cohesivo (ProVisc/Healon)','Red fría','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-149','Blefarostato desechable','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-150','Cistótomo / aguja 27 G','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-151','Cánula de hidrodisección (Rycroft)','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-152','Funda estéril para microscopio','Desechables','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-153','Campo oftálmico con bolsa colectora','Desechables','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-154','Esponjas Weck-Cel','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-155','Protector ocular (concha) y parche','Insumos oftalmológicos','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). salida del paciente',0),
('QX-156','Tobramicina/dexametasona ungüento','Fármacos y colirios','tubo','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-157','Gas SF6 / C3F8 (retina)','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). solo si se hace vitrectomía',0),
('QX-158','Aceite de silicón (retina)','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). solo si se hace vitrectomía',0),
('QX-159','Perfluorocarbono líquido (retina)','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). solo si se hace vitrectomía',0),
('QX-160','Sonda de endoláser','Insumos oftalmológicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato). solo si se hace vitrectomía',0),
('QX-161','Electrodos de repuesto / gel conductor','Insumos médicos','pza','no_critico',false,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('QX-162','Sonda de aspiración / Yankauer','Insumos médicos','pza','critico',true,0,0,1,'quirofano',null,'Sugerido (no venía en el formato).',0),
('CR-001','Epinefrina 1 mg/ml sol. inyectable','Fármacos cardiovasculares (FC)','pza','critico',true,3,1,1,'carro_rojo','Fármacos cardiovasculares (FC)',null,0),
('CR-002','Atropina 1 mg/ml sol. inyectable','Fármacos cardiovasculares (FC)','pza','critico',true,3,1,1,'carro_rojo','Fármacos cardiovasculares (FC)',null,0),
('CR-003','Butilhioscina 20 mg/ml sol. inyectable','Fármacos cardiovasculares (FC)','pza','no_critico',false,2,1,1,'carro_rojo','Fármacos cardiovasculares (FC)',null,19.6),
('CR-004','Efedrina 50 mg/2 ml sol. inyectable','Tensión arterial (TA)','pza','critico',true,2,1,1,'carro_rojo','Tensión arterial (TA)',null,75),
('CR-005','Norepinefrina 4 mg/4 ml sol. inyectable','Shock','pza','critico',true,3,1,1,'carro_rojo','Shock',null,114.5),
('CR-006','Vasopresina 20 UI sol. inyectable','Shock','pza','critico',true,1,0,1,'carro_rojo','Shock',null,445),
('CR-007','Adenosina 6 mg/2 ml sol. inyectable','Shock','pza','critico',true,2,1,1,'carro_rojo','Shock',null,409),
('CR-008','Amiodarona 150 mg/3 ml sol. inyectable','Shock','pza','critico',true,2,1,1,'carro_rojo','Shock',null,65.33),
('CR-009','Verapamilo 5 mg/2 ml sol. inyectable','Shock','pza','critico',true,1,0,1,'carro_rojo','Shock',null,0),
('CR-010','Digoxina 0.5 mg/2 ml sol. inyectable','Shock','pza','critico',true,1,0,1,'carro_rojo','Shock',null,0),
('CR-011','Dopamina 200 mg/5 ml sol. inyectable','Shock','pza','critico',true,1,0,1,'carro_rojo','Shock',null,0),
('CR-012','Dobutamina 250 mg/5 ml','Shock','pza','critico',true,2,1,1,'carro_rojo','Shock',null,250.74),
('CR-013','Avapena (cloropiramina) 20 mg/2 ml sol. inyectable','Anafilaxia','pza','critico',true,2,1,1,'carro_rojo','Anafilaxia',null,79.5),
('CR-014','Difenhidramina 10 mg/ml sol. inyectable','Anafilaxia','pza','critico',true,1,0,1,'carro_rojo','Anafilaxia',null,200),
('CR-015','Hidrocortisona 100 mg sol. inyectable','Anafilaxia','pza','critico',true,1,0,1,'carro_rojo','Anafilaxia',null,95),
('CR-016','Hidrocortisona 500 mg sol. inyectable','Anafilaxia','pza','critico',true,1,0,1,'carro_rojo','Anafilaxia',null,0),
('CR-017','Metilprednisolona 500 mg sol. inyectable','Anafilaxia','pza','critico',true,1,0,1,'carro_rojo','Anafilaxia',null,90.5),
('CR-018','Dexametasona 8 mg/2 ml sol. inyectable','Anafilaxia','pza','critico',true,3,1,1,'carro_rojo','Anafilaxia',null,50),
('CR-019','Alin Depot 4 mg/ml sol. inyectable','Anafilaxia','pza','no_critico',false,1,0,1,'carro_rojo','Anafilaxia',null,189.15),
('CR-020','Sulfato de magnesio 1 g/10 ml sol. inyectable','Electrolitos séricos (ES)','pza','critico',true,1,0,1,'carro_rojo','Electrolitos séricos (ES)',null,85),
('CR-021','Cloruro de potasio 1.49 g/5 ml sol. inyectable','Electrolitos séricos (ES)','pza','critico',true,1,0,1,'carro_rojo','Electrolitos séricos (ES)',null,85),
('CR-022','Cloruro de sodio 17.7% 0.177 g/ml','Electrolitos séricos (ES)','pza','critico',true,1,0,1,'carro_rojo','Electrolitos séricos (ES)',null,0),
('CR-023','Bicarbonato de sodio 7.5% sol. inyectable','Electrolitos séricos (ES)','pza','critico',true,2,1,1,'carro_rojo','Electrolitos séricos (ES)',null,85),
('CR-024','Gluconato de calcio 1 g/10 ml sol. inyectable','Electrolitos séricos (ES)','pza','critico',true,1,0,1,'carro_rojo','Electrolitos séricos (ES)',null,85),
('CR-025','Dicynone 250 mg/2 ml sol. inyectable','Hemostasia','pza','no_critico',false,1,0,1,'carro_rojo','Hemostasia',null,171.4),
('CR-026','Vitamina K 10 sol. inyectable','Hemostasia','pza','no_critico',false,1,0,1,'carro_rojo','Hemostasia',null,0),
('CR-027','Nitroparche (trinitrato de glicerilo) 5 mg/24 h','Infarto agudo (IAM)','pza','critico',true,3,1,1,'carro_rojo','Infarto agudo (IAM)',null,77.4),
('CR-028','Buprenorfina 0.3 mg/ml','Infarto agudo (IAM)','pza','no_critico',false,1,0,1,'carro_rojo','Infarto agudo (IAM)',null,90.8),
('CR-029','Midazolam 15 mg/3 ml sol. inyectable','Anestesia','pza','critico',true,3,1,1,'carro_rojo','Anestesia',null,115),
('CR-030','Midazolam 5 mg/5 ml sol. inyectable','Anestesia','pza','critico',true,3,1,1,'carro_rojo','Anestesia',null,70),
('CR-031','Fentanilo 0.5 mg/10 ml sol. inyectable','Anestesia','pza','critico',true,3,1,1,'carro_rojo','Anestesia',null,300),
('CR-032','Propofol 200 mg/20 ml sol. inyectable','Anestesia','pza','critico',true,3,1,1,'carro_rojo','Anestesia',null,85),
('CR-033','Rocuronio 50 mg/5 ml sol. inyectable','Bloqueo neuromuscular (BNM)','pza','critico',true,4,1,1,'carro_rojo','Bloqueo neuromuscular (BNM)',null,283),
('CR-034','Vecuronio 4 mg sol. inyectable','Bloqueo neuromuscular (BNM)','pza','critico',true,6,1,1,'carro_rojo','Bloqueo neuromuscular (BNM)',null,44),
('CR-035','Cisatracurio 2 mg/ml sol. inyectable','Bloqueo neuromuscular (BNM)','pza','critico',true,1,0,1,'carro_rojo','Bloqueo neuromuscular (BNM)',null,361),
('CR-036','Dexmedetomidina 100 mcg/ml sol. inyectable','Agonista α2','pza','no_critico',false,1,0,1,'carro_rojo','Agonista α2',null,350),
('CR-037','Ropivacaína 7.5% sol. inyectable 20 ml','Anestésicos locales (AL)','pza','critico',true,1,0,1,'carro_rojo','Anestésicos locales (AL)',null,100),
('CR-038','Bupivacaína 5% sol. inyectable','Anestésicos locales (AL)','pza','critico',true,1,0,1,'carro_rojo','Anestésicos locales (AL)',null,0),
('CR-039','Lidocaína 2% sol. inyectable','Anestésicos locales (AL)','pza','critico',true,1,0,1,'carro_rojo','Anestésicos locales (AL)',null,0),
('CR-040','Lidocaína spray','Anestésicos locales (AL)','pza','no_critico',false,1,0,1,'carro_rojo','Anestésicos locales (AL)',null,0),
('CR-041','Bridion (sugammadex) 100 mg/ml sol. inyectable','Antagonistas','pza','critico',true,1,0,1,'carro_rojo','Antagonistas',null,1200),
('CR-042','Prostigmina (neostigmina) 0.5 mg/ml sol. inyectable','Antagonistas','pza','critico',true,1,0,1,'carro_rojo','Antagonistas',null,46.8),
('CR-043','Flumazenil 0.5 mg/5 ml sol. inyectable','Antagonistas','pza','critico',true,1,0,1,'carro_rojo','Antagonistas',null,449),
('CR-044','Aminofilina 250 mg/10 ml sol. inyectable','Respiratorio','pza','critico',true,1,0,1,'carro_rojo','Respiratorio',null,70),
('CR-045','Adrenalina racémica','Respiratorio','pza','critico',true,1,0,1,'carro_rojo','Respiratorio',null,118),
('CR-046','Salbutamol aerosol 100 mcg','Respiratorio','pza','critico',true,1,0,1,'carro_rojo','Respiratorio',null,122),
('CR-047','Pulmicort (budesonida) sol. para nebulizar','Respiratorio','pza','no_critico',false,2,1,1,'carro_rojo','Respiratorio',null,39.75),
('CR-048','Omeprazol 40 mg sol. inyectable','Protector gástrico (IBP)','pza','no_critico',false,1,0,1,'carro_rojo','Protector gástrico (IBP)',null,55),
('CR-049','Metoclopramida 10 mg/ml sol. inyectable','Náusea y vómito (NVPO)','pza','no_critico',false,2,1,1,'carro_rojo','Náusea y vómito (NVPO)',null,7.7),
('CR-050','Difenidol 40 mg/2 ml sol. inyectable','Náusea y vómito (NVPO)','pza','no_critico',false,1,0,1,'carro_rojo','Náusea y vómito (NVPO)',null,21),
('CR-051','Ondansetrón 8 mg/4 ml sol. inyectable','Náusea y vómito (NVPO)','pza','no_critico',false,2,1,1,'carro_rojo','Náusea y vómito (NVPO)',null,38.45),
('CR-052','Supradol (ketorolaco) 30 mg tabletas','Analgesia','pza','no_critico',false,2,1,1,'carro_rojo','Analgesia',null,0),
('CR-053','Supradol (ketorolaco) 10 mg tabletas','Analgesia','pza','no_critico',false,2,1,1,'carro_rojo','Analgesia',null,0),
('CR-054','Supradol Duet 10 mg/25 mg tabletas','Analgesia','pza','no_critico',false,2,1,1,'carro_rojo','Analgesia',null,0),
('CR-055','Paracetamol 650 mg tabletas','Analgesia','pza','no_critico',false,12,1,1,'carro_rojo','Analgesia',null,5),
('CR-056','Ketorolaco 30 mg sol. inyectable','Analgesia','pza','no_critico',false,3,1,1,'carro_rojo','Analgesia',null,15),
('CR-057','Metamizol 1 g sol. inyectable','Analgesia','pza','no_critico',false,3,1,1,'carro_rojo','Analgesia',null,16.3),
('CR-058','Supradol Duet 10 mg/25 mg sol. inyectable','Analgesia','pza','no_critico',false,1,0,1,'carro_rojo','Analgesia',null,0),
('CR-059','Captopril 25 mg tabletas','Antihipertensivos','pza','no_critico',false,15,1,1,'carro_rojo','Antihipertensivos',null,0.85),
('CR-060','Nifedipino 10 mg tabletas','Antihipertensivos','pza','no_critico',false,20,1,1,'carro_rojo','Antihipertensivos',null,1.1),
('CR-061','Hidralazina 20 mg/ml sol. inyectable','Antihipertensivos','pza','no_critico',false,1,0,1,'carro_rojo','Antihipertensivos',null,0),
('CR-062','Labetalol 100 mg/20 ml sol. inyectable','Antihipertensivos','pza','no_critico',false,1,0,1,'carro_rojo','Antihipertensivos',null,0),
('CR-063','Nitroglicerina','Antihipertensivos','pza','no_critico',false,1,0,1,'carro_rojo','Antihipertensivos',null,0),
('CR-064','Dinitrato de isosorbida tableta sublingual','Antihipertensivos','pza','no_critico',false,1,0,1,'carro_rojo','Antihipertensivos',null,0),
('CR-065','Heparina 1000 UI/ml sol. inyectable','Otros','pza','no_critico',false,1,0,1,'carro_rojo','Otros',null,120),
('CR-066','Fenitoína 250 mg/ml sol. inyectable','Otros','pza','critico',true,1,0,1,'carro_rojo','Otros',null,71.69),
('CR-067','Furosemida 20 mg/2 ml','Otros','pza','no_critico',false,2,1,1,'carro_rojo','Otros',null,14.25),
('CR-068','Ceftriaxona 1 g sol. inyectable','Antibiótico','pza','no_critico',false,1,0,1,'carro_rojo','Antibiótico',null,50),
('CR-069','Sevoflurano para inhalación','Inductor','pza','critico',true,1,0,1,'carro_rojo','Inductor',null,0),
('CR-070','Glucosa al 50%','Diabetes (DM)','pza','critico',true,1,0,1,'carro_rojo','Diabetes (DM)',null,0),
('CR-071','Insulina de acción rápida (IAR)','Diabetes (DM)','pza','critico',true,1,0,1,'carro_rojo','Diabetes (DM)',null,0),
('CR-072','Naloxona 0.4 mg/ml sol. inyectable','Antagonistas','pza','critico',true,2,0,1,'carro_rojo','Antagonistas','Sugerido (no venía en la lista). antagonista de opioides (no venía en la lista)',0),
('CR-073','Emulsión lipídica 20% (Intralipid) 500 ml','Anestésicos locales (AL)','pza','critico',true,1,0,1,'carro_rojo','Anestésicos locales (AL)','Sugerido (no venía en la lista). rescate por toxicidad de anestésico local (bloqueos retrobulbares)',0),
('CR-074','Dantroleno 20 mg frasco ámpula','Inductor','pza','critico',true,0,0,1,'carro_rojo','Inductor','Sugerido (no venía en la lista). hipertermia maligna si se usa sevoflurano: definir cantidad con anestesiología',0),
('CR-075','Solución fisiológica 0.9% 1000 ml','Soluciones','pza','critico',true,2,0,1,'carro_rojo','Soluciones','Sugerido (no venía en la lista).',0),
('CR-076','Solución Hartmann 1000 ml','Soluciones','pza','critico',true,2,0,1,'carro_rojo','Soluciones','Sugerido (no venía en la lista).',0),
('CR-077','Bolsa-válvula-mascarilla (Ambu) adulto','Vía aérea y equipo','pza','critico',true,1,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-078','Cánulas de Guedel (juego de tallas)','Vía aérea y equipo','pza','critico',true,1,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-079','Mascarilla laríngea #3 y #4','Vía aérea y equipo','pza','critico',true,2,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-080','Tubos endotraqueales 6.5 / 7.0 / 7.5','Vía aérea y equipo','pza','critico',true,3,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-081','Laringoscopio con hojas y pilas de repuesto','Vía aérea y equipo','pza','critico',true,1,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-082','Electrodos para desfibrilador / monitor','Vía aérea y equipo','pza','critico',true,1,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0),
('CR-083','Glucómetro con tiras','Vía aérea y equipo','pza','critico',true,1,0,1,'carro_rojo','Vía aérea y equipo','Sugerido (no venía en la lista).',0)
on conflict (codigo) where codigo is not null do nothing;
-- existencias iniciales (solo si el material aún no tiene lotes)
insert into qx_lotes(material_id,ubicacion_id,lote,caducidad,cantidad)
select m.id,u.id,x.lote,x.cad::date,x.cant from (values
('QX-002','almacen','INICIAL','2029-05-31',9),
('QX-003','almacen','INICIAL','2027-08-31',1),
('QX-004','almacen','INICIAL','2027-07-31',1),
('QX-008','almacen','INICIAL','2028-01-31',2),
('QX-010','almacen','INICIAL','2027-03-31',9),
('QX-013','almacen','INICIAL','2030-02-28',1),
('QX-014','almacen','INICIAL','2027-03-31',5),
('QX-015','almacen','INICIAL','2026-09-30',3),
('QX-016','almacen','INICIAL','2028-02-29',3),
('QX-017','almacen','INICIAL','2026-12-31',1),
('QX-018','almacen','INICIAL','2027-05-31',1),
('QX-020','almacen','INICIAL','2028-09-30',1),
('QX-021','almacen','INICIAL',null,1),
('QX-026','almacen','INICIAL','2028-03-31',4),
('QX-027','almacen','INICIAL','2026-10-31',6),
('QX-028','almacen','INICIAL','2026-11-30',2),
('QX-029','almacen','INICIAL','2027-01-31',12),
('QX-030','almacen','INICIAL',null,10),
('QX-031','almacen','INICIAL','2026-11-30',2),
('QX-032','almacen','INICIAL','2029-05-31',1),
('QX-035','almacen','INICIAL','2026-09-30',6),
('QX-037','almacen','INICIAL',null,3),
('QX-038','almacen','INICIAL','2026-10-31',3),
('QX-039','almacen','INICIAL','2027-01-31',4),
('QX-040','almacen','INICIAL',null,32),
('QX-041','almacen','INICIAL',null,1),
('QX-042','almacen','INICIAL','2028-07-31',300),
('QX-043','almacen','INICIAL',null,30),
('QX-044','almacen','INICIAL','2027-01-31',7),
('QX-045','almacen','INICIAL','2028-07-31',1),
('QX-046','almacen','INICIAL','2026-12-31',7),
('QX-049','almacen','INICIAL','2026-11-30',13),
('QX-051','almacen','INICIAL','2030-11-30',27),
('QX-055','almacen','INICIAL',null,5),
('QX-056','almacen','INICIAL',null,2),
('QX-057','almacen','INICIAL','2030-10-31',1),
('QX-058','almacen','INICIAL',null,1),
('QX-059','almacen','INICIAL',null,1),
('QX-061','almacen','INICIAL','2030-11-30',1),
('QX-062','almacen','INICIAL','2027-09-30',4),
('QX-063','almacen','INICIAL','2029-02-28',25),
('QX-064','almacen','INICIAL','2030-04-30',61),
('QX-065','almacen','INICIAL','2030-02-28',76),
('QX-066','almacen','INICIAL','2030-08-31',190),
('QX-067','almacen','INICIAL','2030-11-30',99),
('QX-068','almacen','INICIAL','2030-09-30',51),
('QX-069','almacen','INICIAL','2031-03-31',38),
('QX-071','almacen','INICIAL','2027-11-30',16),
('QX-072','almacen','INICIAL','2030-11-30',17),
('QX-073','almacen','INICIAL','2024-08-31',10),
('QX-074','almacen','INICIAL','2026-11-30',2),
('QX-075','almacen','INICIAL','2026-11-30',28),
('QX-076','almacen','INICIAL','2028-01-31',1),
('QX-077','almacen','INICIAL','2030-09-30',46),
('QX-079','almacen','INICIAL','2028-07-31',76),
('QX-080','almacen','INICIAL','2030-08-31',11),
('QX-081','almacen','INICIAL','2030-08-31',8),
('QX-082','almacen','INICIAL','2030-07-31',15),
('QX-083','almacen','INICIAL',null,1),
('QX-084','almacen','INICIAL','2030-06-30',5),
('QX-085','almacen','INICIAL','2030-04-30',9),
('QX-086','almacen','INICIAL','2029-04-30',96),
('QX-089','almacen','INICIAL','2027-04-30',68),
('QX-090','almacen','INICIAL',null,2),
('QX-091','almacen','INICIAL','2026-09-30',11),
('QX-092','almacen','INICIAL','2026-09-30',3),
('QX-093','almacen','INICIAL',null,158),
('QX-096','almacen','INICIAL',null,176),
('QX-097','almacen','INICIAL',null,84),
('QX-098','almacen','INICIAL',null,164),
('QX-099','almacen','INICIAL','2029-04-30',58),
('QX-100','almacen','INICIAL','2029-05-31',51),
('QX-101','almacen','INICIAL',null,1),
('QX-102','almacen','INICIAL','2026-11-30',4),
('QX-105','almacen','INICIAL','2027-02-28',17),
('QX-106','almacen','INICIAL','2030-10-31',40),
('QX-107','almacen','INICIAL','2031-04-30',57),
('QX-108','almacen','INICIAL','2030-11-30',50),
('QX-111','almacen','INICIAL','2026-08-31',47),
('QX-114','almacen','INICIAL','2027-10-31',5),
('QX-116','almacen','INICIAL','2027-09-30',2),
('QX-120','almacen','INICIAL','2027-11-30',1),
('QX-123','almacen','INICIAL',null,1),
('QX-125','almacen','INICIAL','2027-07-31',1),
('QX-127','almacen','INICIAL',null,10),
('QX-128','almacen','INICIAL',null,1),
('QX-130','almacen','INICIAL',null,189),
('QX-131','almacen','INICIAL',null,28),
('QX-132','almacen','INICIAL',null,200),
('QX-133','almacen','INICIAL',null,473),
('QX-134','almacen','INICIAL',null,1037),
('QX-136','almacen','INICIAL','2027-01-31',42),
('QX-138','almacen','INICIAL','2026-12-31',1),
('QX-139','almacen','INICIAL','2026-12-31',11),
('QX-140','almacen','INICIAL','2026-11-30',43),
('QX-142','almacen','INICIAL','2027-09-30',3),
('CR-001','carro','B23F559','2025-02-28',1),
('CR-001','carro','B24Y244','2026-05-31',2),
('CR-002','carro','2303031','2025-03-31',1),
('CR-002','carro','2303021','2025-03-31',1),
('CR-002','carro','2406062','2026-06-30',1),
('CR-003','carro','B2A212','2026-02-28',2),
('CR-004','carro','B23F532','2026-02-28',2),
('CR-005','carro','B23Y948','2025-05-31',3),
('CR-006','carro','C24U419','2026-07-31',1),
('CR-007','carro','C24U418','2026-07-31',2),
('CR-008','carro','B24M037','2026-03-31',2),
('CR-012','carro','B24Y288','2026-05-31',2),
('CR-013','carro','NK5353','2025-09-30',2),
('CR-014','carro','DH00823','2025-03-31',1),
('CR-015','carro','Z23N191','2025-11-30',1),
('CR-017','carro','C23T867','2025-10-31',1),
('CR-018','carro','B24F957','2027-02-28',1),
('CR-018','carro','BCK083','2028-02-29',1),
('CR-018','carro','BDB112','2028-02-29',1),
('CR-019','carro','BBM018','2025-12-31',1),
('CR-020','carro','R24E07','2026-01-31',1),
('CR-021','carro','B23S413','2028-09-30',1),
('CR-022','carro','B22Y391','2024-11-30',1),
('CR-023','carro','C22G870','2025-08-31',2),
('CR-024','carro','B23G316','2025-08-31',1),
('CR-025','carro','N1333','2026-03-31',1),
('CR-027','carro','104756','2026-09-30',3),
('CR-028','carro','B23A798','2025-04-30',1),
('CR-029','carro','B23G206','2025-08-31',3),
('CR-030','carro','B23U129','2025-07-31',1),
('CR-030','carro','B23N600','2025-11-30',2),
('CR-031','carro','B23S364','2026-09-30',1),
('CR-031','carro','B24Y345','2027-05-31',2),
('CR-032','carro','XC2301','2025-03-31',3),
('CR-033','carro','C24M128','2026-03-31',4),
('CR-034','carro','T24Y247','2026-05-31',6),
('CR-035','carro','B24Y362','2026-05-31',1),
('CR-036','carro','C23T866','2025-10-31',1),
('CR-037','carro','23S02','2025-09-30',1),
('CR-038','carro','B21D786','2024-12-31',1),
('CR-041','carro','A102961','2025-06-30',1),
('CR-042','carro','400482','2026-06-30',1),
('CR-043','carro','B22G886','2025-08-31',1),
('CR-044','carro','B22E918','2026-01-31',1),
('CR-045','carro','326641','2025-05-31',1),
('CR-046','carro','4F895','2027-06-30',1),
('CR-047','carro','SELR','2025-08-31',2),
('CR-048','carro','MMNN',null,1),
('CR-049','carro','R23U67','2025-07-31',2),
('CR-050','carro','SIN LOTE','2025-05-31',1),
('CR-051','carro','M2404169','2027-04-30',2),
('CR-052','carro','H10363','2026-10-31',2),
('CR-053','carro','C06187','2025-06-30',2),
('CR-054','carro','J02299','2026-02-28',2),
('CR-055','carro','ABB1351','2026-08-31',12),
('CR-056','carro','R23Y54','2025-05-31',3),
('CR-057','carro','SIN LOTE',null,3),
('CR-058','carro','J01100','2026-01-31',1),
('CR-059','carro','550033','2025-03-31',15),
('CR-060','carro','232087','2025-09-30',20),
('CR-061','carro','H122E01','2024-05-31',1),
('CR-064','carro','SIN LOTE',null,1),
('CR-065','carro','C23D952','2026-12-31',1),
('CR-066','carro','B24F849','2026-02-28',1),
('CR-067','carro','R24A15','2026-04-30',2),
('CR-068','carro','J24J072','2025-10-31',1),
('CR-069','carro','S281L327','2025-11-30',1)
) as x(cod,ub,lote,cad,cant)
join qx_materiales m on m.codigo=x.cod
join qx_sedes s on s.nombre like 'Tac%'
join qx_ubicaciones u on u.sede_id=s.id and ((x.ub='carro' and u.tipo='carro') or (x.ub='almacen' and u.tipo='almacen'))
where not exists (select 1 from qx_lotes l where l.material_id=m.id);
-- lentes intraoculares en existencia (se cargan una sola vez)
insert into qx_lio_unidades(marca,modelo,tipo,dioptria,caducidad,lote,propiedad,ubicacion_id,estado,notas)
select x.marca,x.modelo,x.tipo,x.d,x.cad::date,'INICIAL','propio',u.id,'disponible','Carga inicial: capturar número de serie' from (values
('Ophtec','Iris Claw','Fijación iridiana',16.0,'2027-01-31'),
('Ophtec','Iris Claw','Fijación iridiana',17.0,'2027-08-31'),
('Ophtec','Iris Claw','Fijación iridiana',19.0,'2028-04-30'),
('Ophtec','Iris Claw','Fijación iridiana',21.0,'2027-08-31'),
('Ophtec','Iris Claw','Fijación iridiana',21.0,'2027-08-31'),
('Ophtec','Iris Claw','Fijación iridiana',22.0,'2026-10-31'),
('Ophtec','Iris Claw','Fijación iridiana',22.0,'2027-07-31'),
('Ophtec','Iris Claw','Fijación iridiana',23.0,'2026-07-31'),
('Ophtec','Iris Claw','Fijación iridiana',24.0,'2026-07-31'),
('Hoya','Hoya 1 pieza','Monofocal',17.0,'2028-02-29'),
('Hoya','Hoya 1 pieza','Monofocal',19.0,'2028-09-30'),
('Hoya','Hoya 1 pieza','Monofocal',20.0,'2029-04-30'),
('Hoya','Hoya 1 pieza','Monofocal',20.0,'2029-04-30'),
('Hoya','Hoya 1 pieza','Monofocal',20.5,'2028-09-30'),
('Hoya','Hoya 1 pieza','Monofocal',21.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.5,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.5,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',21.5,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.0,'2029-05-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.5,'2028-10-31'),
('Hoya','Hoya 1 pieza','Monofocal',22.5,'2028-10-31'),
('Hoya','Hoya 1 pieza','Monofocal',23.0,'2028-07-31'),
('Hoya','Hoya 1 pieza','Monofocal',23.0,'2028-07-31'),
('Hoya','Hoya 1 pieza','Monofocal',24.0,'2028-12-31')
) as x(marca,modelo,tipo,d,cad)
join qx_sedes s on s.nombre like 'Tac%'
join qx_ubicaciones u on u.sede_id=s.id and u.tipo='almacen'
where not exists (select 1 from qx_lio_unidades where lote='INICIAL');

-- ============================================================
-- v2.6 · Foto de la caja del LIO, avisos a Finanzas, indicaciones y papelería
-- ============================================================
alter table qx_cirugia_evidencias drop constraint if exists qx_cirugia_evidencias_tipo_check;
alter table qx_cirugia_evidencias add constraint qx_cirugia_evidencias_tipo_check
  check (tipo in ('anticipo','abono','liquidacion','reembolso','consentimiento','biometria','valoracion','lio_caja','otro'));
insert into qx_config(clave,valor) values
  ('lio_aviso_dias','90'),                                            -- aviso a Finanzas antes de caducar un LIO
  ('medicos_cedulas','Dr. José Antonio Villegas Ávila|7256707|9457035') -- nombre|cédula|cédula de especialidad (uno por renglón)
on conflict do nothing;

-- ============================================================
-- v3.1 · Lectura automática de comprobantes y tema claro
-- ============================================================
alter table qx_cirugia_evidencias add column if not exists lectura jsonb;  -- montos leídos, coincide, motivo
insert into qx_config(clave,valor) values ('tema','claro') on conflict do nothing;

-- ============================================================
-- v3.3 · Directorio de pacientes (importado del sistema anterior de cotizaciones)
-- ============================================================
create table if not exists qx_pacientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null, expediente text, telefono1 text, telefono2 text,
  sede_id uuid references qx_sedes(id),
  origen text, origen_id text,            -- cotizaciones | cotizaciones_s2 | qx
  ultima_cotizacion timestamptz, notas text,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create unique index if not exists qx_pacientes_origen_uk on qx_pacientes(origen,origen_id);
create index if not exists qx_pacientes_nombre_ix on qx_pacientes(lower(nombre));
alter table qx_pacientes enable row level security;
drop policy if exists qx_pacientes_all on qx_pacientes;
create policy qx_pacientes_all on qx_pacientes for all to public using (true) with check (true);

insert into qx_pacientes(nombre,expediente,telefono1,telefono2,sede_id,origen,origen_id,ultima_cotizacion)
select distinct on (lower(trim(c.nombre)),coalesce(nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),'-'))
  trim(c.nombre),nullif(trim(c.expediente),''),nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),nullif(regexp_replace(coalesce(c.tel2,''),'\D','','g'),''),
  (select id from qx_sedes where nombre like 'Tac%' limit 1),'cotizaciones',c.id,coalesce(c.updated_at,c.created_at)
from cotizaciones c where coalesce(trim(c.nombre),'')<>''
order by lower(trim(c.nombre)),coalesce(nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),'-'),coalesce(c.updated_at,c.created_at) desc
on conflict (origen,origen_id) do nothing;

insert into qx_pacientes(nombre,telefono1,telefono2,sede_id,origen,origen_id,ultima_cotizacion)
select distinct on (lower(trim(c.nombre)),coalesce(nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),'-'))
  trim(c.nombre),nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),nullif(regexp_replace(coalesce(c.tel2,''),'\D','','g'),''),
  (select id from qx_sedes where nombre like 'Mor%' limit 1),'cotizaciones_s2',c.id,coalesce(c.updated_at,c.created_at)
from cotizaciones_s2 c where coalesce(trim(c.nombre),'')<>''
order by lower(trim(c.nombre)),coalesce(nullif(regexp_replace(coalesce(c.tel1,''),'\D','','g'),''),'-'),coalesce(c.updated_at,c.created_at) desc
on conflict (origen,origen_id) do nothing;

-- v2.7 · Campañas de cirugía
create table if not exists qx_campanas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null, notas text, dias jsonb default '[]'::jsonb,
  activa boolean not null default false, sede_id uuid references qx_sedes(id),
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists qx_campana_pacientes (
  id uuid primary key default gen_random_uuid(),
  campana_id uuid not null references qx_campanas(id) on delete cascade,
  cotizacion_id uuid, item int, paciente_nombre text not null, telefono text, expediente text,
  ojo text, procedimiento text, lio_tipo text, lio_poder numeric, monto_total numeric default 0,
  dia date, notas text, comprobantes jsonb default '[]'::jsonb, creado_por text,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create index if not exists qx_camp_pac_c on qx_campana_pacientes(campana_id);
do $$ declare t text; begin
  foreach t in array array['qx_campanas','qx_campana_pacientes','qx_pacientes','qx_escalamientos'] loop
    execute format('alter table %I enable row level security', t);
    if not exists (select 1 from pg_policies where tablename=t and policyname=t||'_all') then
      execute format('create policy %I on %I for all to public using (true) with check (true)', t||'_all', t);
    end if;
    begin execute format('alter publication supabase_realtime add table %I', t); exception when others then null; end;
  end loop;
end $$;
-- v3.6 · Importación del historial de cotizaciones (COE Cirugías) a qx_cotizaciones: aplicada como migración qx_importar_cotizaciones_anteriores (idempotente por origen,origen_id)
-- v3.11 · Almacén de Administración: qx_ubicaciones.area ('administracion'|'quirofano'), qx_movimientos.envio (folio de envío) · migración qx_almacen_administracion
alter table qx_ubicaciones add column if not exists area text not null default 'quirofano';
insert into qx_ubicaciones(sede_id,nombre,tipo,orden,area) select s.id,'Almacén de Administración','almacen',-1,'administracion' from qx_sedes s where s.nombre like 'Tac%' and not exists (select 1 from qx_ubicaciones u where u.sede_id=s.id and u.area='administracion');
alter table qx_movimientos add column if not exists envio text;
alter table qx_cotizaciones add column if not exists anestesia text;
-- v3.13 · Sincronización automática: triggers qx_sync_cot_t (cotizaciones) y qx_sync_cot_s2 (cotizaciones_s2) copian cada alta o cambio de la app anterior a qx_cotizaciones y qx_pacientes · migración qx_sync_cotizaciones_anteriores
-- v3.14/3.15 · qx_lotes.consignacion/proveedor, qx_movimientos.consignacion/documento_url (llegadas con documento y consigna); qx_cirugias.consigna jsonb (material en consigna por cirugía y documentos)
