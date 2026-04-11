# GanApp Backend (Firebase Functions)

Backend API REST para GanApp, pensado para trabajar con Flutter en modo offline-first y sincronizacion incremental.

## Stack

- Firebase Functions v2 + Express
- Firestore como base de datos
- Firebase Auth para autenticacion
- Zod para validacion de payloads

## Estructura principal

- `src/routes`: endpoints REST
- `src/services`: logica de acceso a datos por recurso
- `src/types`: modelos de dominio
- `src/validation`: reglas de validacion
- `src/middleware`: seguridad y auth

## Recursos implementados

- Usuarios (`users`)
- Vacas (`vacas`)
- Produccion de leche (`prod_leche`)
- Eventos reproductivos (`eventos_reproductivos`)
- Eventos veterinarios (`eventos_veterinarios`)
- Historial de crecimiento (`historial_crecimiento`)

## Auth

Las rutas protegidas esperan `Authorization: Bearer <firebase_id_token>`.

### Registro inicial

`POST /api/v1/auth/register`

Body ejemplo:

```json
{
  "email": "admin@ganapp.com",
  "password": "12345678",
  "nombre": "Carlos Perez",
  "nombreFinca": "La Esperanza",
  "tipoUsuarioId": "ganadero"
}
```

## Rutas por modulo

Cada modulo sigue este patron:

- `GET /api/v1/<modulo>`
- `GET /api/v1/<modulo>/:id`
- `POST /api/v1/<modulo>`
- `PATCH /api/v1/<modulo>/:id`
- `DELETE /api/v1/<modulo>/:id` (borrado logico)

## Sync incremental

`GET /api/v1/sync/pull?since=2026-01-01T00:00:00.000Z`

Retorna solo cambios (incluyendo bajas logicas) desde la fecha indicada para el usuario autenticado.

## Ejecutar local

1. Instalar Firebase CLI si no la tienes.
2. Desde `functions/`:

```bash
npm install
npm run serve
```

## Desplegar

```bash
firebase login
firebase use <tu-proyecto>
cd functions
npm install
npm run deploy
```

## Notas de modelado

- Todos los documentos incluyen `ownerUid`, `createdAt`, `updatedAt`, `deletedAt`, `isDeleted`.
- El backend esta preparado para cache local en SQLite en Flutter gracias a `updatedAt` + endpoint de sync.