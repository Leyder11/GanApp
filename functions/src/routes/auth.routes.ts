import { FieldValue } from "firebase-admin/firestore";
import { Router } from "express";
import { auth, db } from "../config/firebase";
import { COLLECTIONS } from "../types/entities";
import { errorResponse, successResponse } from "../utils/http";
import { forgotPasswordSchema, loginSchema, registerSchema } from "../validation/schemas";

export const authRouter = Router();

authRouter.post("/forgot-password", async (req, res) => {
  const parsed = forgotPasswordSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos invalidos.", parsed.error.flatten());
  }

  const apiKey = process.env.GANAPP_WEB_API_KEY ?? process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    return errorResponse(
      res,
      500,
      "MISSING_FIREBASE_WEB_API_KEY",
      "Configura FIREBASE_WEB_API_KEY para habilitar recuperacion de contrasena.",
    );
  }

  try {
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requestType: "PASSWORD_RESET",
          email: parsed.data.email,
        }),
      },
    );

    const payload = (await response.json()) as { error?: { message?: string } };

    if (!response.ok) {
      return errorResponse(
        res,
        400,
        "FORGOT_PASSWORD_FAILED",
        "No se pudo enviar el correo de recuperacion.",
        payload.error?.message,
      );
    }

    return successResponse(res, {
      email: parsed.data.email,
      sent: true,
      message: "Si el correo existe, se envio el enlace de recuperacion.",
    });
  } catch (error) {
    console.error(error);
    return errorResponse(res, 500, "FORGOT_PASSWORD_FAILED", "No se pudo completar la recuperacion.");
  }
});

authRouter.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos de login invalidos.", parsed.error.flatten());
  }

  const apiKey = process.env.GANAPP_WEB_API_KEY ?? process.env.FIREBASE_WEB_API_KEY;
  if (!apiKey) {
    return errorResponse(
      res,
      500,
      "MISSING_FIREBASE_WEB_API_KEY",
      "Configura FIREBASE_WEB_API_KEY para habilitar login por email y contrasena.",
    );
  }

  const { email, password } = parsed.data;

  try {
    const firebaseLoginResponse = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          email,
          password,
          returnSecureToken: true,
        }),
      },
    );

    const loginPayload = (await firebaseLoginResponse.json()) as {
      localId?: string;
      idToken?: string;
      email?: string;
      displayName?: string;
      error?: { message?: string };
    };

    if (!firebaseLoginResponse.ok || !loginPayload.localId || !loginPayload.idToken) {
      return errorResponse(
        res,
        401,
        "INVALID_CREDENTIALS",
        "Credenciales invalidas.",
        loginPayload.error?.message,
      );
    }

    const userProfileRef = db.collection(COLLECTIONS.users).doc(loginPayload.localId);
    const userProfileDoc = await userProfileRef.get();

    let userProfile = userProfileDoc.data() ?? {};
    if (userProfileDoc.exists) {
      await userProfileRef.update({
        ultimaConexion: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      // Auto-recupera cuentas antiguas que existen en Auth pero no en users/farms.
      const farmRef = await db.collection(COLLECTIONS.farms).add({
        nombre: "Mi Finca Principal",
        ownerUid: loginPayload.localId,
        isDeleted: false,
        deletedAt: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      await userProfileRef.set({
        uid: loginPayload.localId,
        ownerUid: loginPayload.localId,
        nombre: loginPayload.displayName ?? "Ganadero",
        email: loginPayload.email ?? email,
        nombreFinca: "Mi Finca Principal",
        currentFarmId: farmRef.id,
        tipoUsuarioId: "ganadero",
        isDeleted: false,
        deletedAt: null,
        fechaRegistro: FieldValue.serverTimestamp(),
        ultimaConexion: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      const hydratedDoc = await userProfileRef.get();
      userProfile = hydratedDoc.data() ?? {};
    }

    return successResponse(res, {
      uid: loginPayload.localId,
      email: loginPayload.email ?? email,
      nombre: (userProfile.nombre as string | undefined) ?? loginPayload.displayName ?? "Ganadero",
      token: loginPayload.idToken,
    });
  } catch (error) {
    console.error(error);
    return errorResponse(res, 500, "LOGIN_FAILED", "No se pudo completar el login.");
  }
});

authRouter.post("/register", async (req, res) => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    return errorResponse(res, 400, "INVALID_PAYLOAD", "Datos de registro invalidos.", parsed.error.flatten());
  }

  const { email, password, nombre, nombreFinca, tipoUsuarioId } = parsed.data;

  try {
    const userRecord = await auth.createUser({
      email,
      password,
      displayName: nombre,
    });

    const farmRef = await db.collection(COLLECTIONS.farms).add({
      nombre: nombreFinca ?? "Mi Finca Principal",
      ownerUid: userRecord.uid,
      isDeleted: false,
      deletedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    await db.collection(COLLECTIONS.users).doc(userRecord.uid).set({
      uid: userRecord.uid,
      ownerUid: userRecord.uid,
      nombre,
      email,
      nombreFinca: nombreFinca ?? "Mi Finca Principal",
      currentFarmId: farmRef.id,
      tipoUsuarioId,
      isDeleted: false,
      deletedAt: null,
      fechaRegistro: FieldValue.serverTimestamp(),
      ultimaConexion: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return successResponse(
      res,
      {
        uid: userRecord.uid,
        email: userRecord.email,
      },
      201,
    );
  } catch (error) {
    console.error(error);
    const details =
      error && typeof error === "object"
        ? {
            code: (error as { code?: unknown }).code,
            message: (error as { message?: unknown }).message,
          }
        : undefined;

    return errorResponse(
      res,
      409,
      "REGISTER_FAILED",
      "No se pudo registrar el usuario. Verifica Firestore/Auth en Firebase o si el email ya existe.",
      details,
    );
  }
});