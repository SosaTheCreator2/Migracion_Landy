-- Changing the columns in a view requires dropping and re-creating the view.
-- This may fail if other objects are dependent upon this view,
-- or may cause procedural functions to fail if they are not modified to
-- take account of the changes.
DROP VIEW public.vw_solicitud_detalle_progreso;

CREATE OR REPLACE VIEW public.vw_solicitud_detalle_progreso
    AS
     SELECT d.id_empresa,
    d.id_solicitud_detalle,
    d.id_solicitud,
    d.id_producto,
    d.id_unidad_medida,
    COALESCE(NULLIF(btrim(u.abreviatura::text), ''::text), u.nombre::text) AS unidad,
    d.cantidad_solicitada,
    COALESCE(sum(
        CASE
            WHEN p.estatus::text = ANY (ARRAY['Cancelado'::character varying, 'Rechazado'::character varying]::text[]) THEN 0::numeric
            WHEN pd.respuesta IS NULL THEN pd.cantidad_solicitada
            WHEN pd.respuesta::text = ANY (ARRAY['Aceptar'::character varying, 'Modificar'::character varying]::text[]) THEN COALESCE(pd.cantidad_confirmada, 0::numeric)
            ELSE 0::numeric
        END), 0::numeric) AS cantidad_comprometida,
    COALESCE(sum(
        CASE
            WHEN (p.estatus::text <> ALL (ARRAY['Cancelado'::character varying, 'Rechazado'::character varying]::text[])) AND (pd.respuesta::text = ANY (ARRAY['Aceptar'::character varying, 'Modificar'::character varying]::text[])) THEN COALESCE(pd.cantidad_confirmada, 0::numeric)
            ELSE 0::numeric
        END), 0::numeric) AS cantidad_confirmada,
    d.cantidad_solicitada - COALESCE(sum(
        CASE
            WHEN p.estatus::text = ANY (ARRAY['Cancelado'::character varying, 'Rechazado'::character varying]::text[]) THEN 0::numeric
            WHEN pd.respuesta IS NULL THEN pd.cantidad_solicitada
            WHEN pd.respuesta::text = ANY (ARRAY['Aceptar'::character varying, 'Modificar'::character varying]::text[]) THEN COALESCE(pd.cantidad_confirmada, 0::numeric)
            ELSE 0::numeric
        END), 0::numeric) AS cantidad_pendiente_asignar,
    COALESCE(sum(
        CASE
            WHEN (p.estatus::text <> ALL (ARRAY['Cancelado'::character varying, 'Rechazado'::character varying]::text[])) AND pd.respuesta IS NULL THEN pd.cantidad_solicitada
            ELSE 0::numeric
        END), 0::numeric) AS cantidad_pendiente_confirmar
   FROM solicitud_traspaso_detalle d
     JOIN cat_unidades_medida u ON u.id = d.id_unidad_medida
     LEFT JOIN pedido_transferencia_detalle pd ON pd.id_solicitud_detalle = d.id_solicitud_detalle AND pd.id_empresa = d.id_empresa
     LEFT JOIN pedidos_transferencia p ON p.id_pedido = pd.id_pedido AND p.id_empresa = pd.id_empresa
  GROUP BY d.id_empresa, d.id_solicitud_detalle, d.id_solicitud, d.id_producto, d.id_unidad_medida, u.abreviatura, u.nombre, d.cantidad_solicitada;

ALTER TABLE public.vw_solicitud_detalle_progreso
    OWNER TO landiadm;