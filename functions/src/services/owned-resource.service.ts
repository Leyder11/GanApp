import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { db } from "../config/firebase";
import { mapDoc } from "../utils/firestore";

type QueryOptions = {
  includeDeleted?: boolean;
  since?: string;
};

export class OwnedResourceService<TCreate extends object, TUpdate extends object> {
  constructor(private readonly collectionName: string) {}

  async create(ownerUid: string, payload: TCreate): Promise<Record<string, unknown>> {
    const payloadWithAudit = {
      ...payload,
      ownerUid,
      isDeleted: false,
      deletedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    const createdRef = await db.collection(this.collectionName).add(payloadWithAudit);
    const createdDoc = await createdRef.get();
    return mapDoc<Record<string, unknown>>(createdDoc.id, createdDoc.data() ?? {});
  }

  async list(ownerUid: string, options?: QueryOptions): Promise<Array<Record<string, unknown>>> {
    const includeDeleted = options?.includeDeleted ?? false;
    let query = db.collection(this.collectionName).where("ownerUid", "==", ownerUid);

    if (!includeDeleted) {
      query = query.where("isDeleted", "==", false);
    }

    if (options?.since) {
      const sinceDate = new Date(options.since);
      if (!Number.isNaN(sinceDate.getTime())) {
        query = query.where("updatedAt", ">=", Timestamp.fromDate(sinceDate));
      }
    }

    try {
      const snapshot = await query.orderBy("updatedAt", "desc").get();
      return snapshot.docs.map((doc) => mapDoc<Record<string, unknown>>(doc.id, doc.data()));
    } catch (error) {
      console.error(`List fallback for ${this.collectionName}:`, error);
      const snapshot = await query.get();
      return snapshot.docs.map((doc) => mapDoc<Record<string, unknown>>(doc.id, doc.data()));
    }
  }

  async findById(ownerUid: string, id: string): Promise<Record<string, unknown> | null> {
    const doc = await db.collection(this.collectionName).doc(id).get();
    if (!doc.exists) {
      return null;
    }

    const data = doc.data();
    if (!data || data.ownerUid !== ownerUid) {
      return null;
    }

    return mapDoc<Record<string, unknown>>(doc.id, data);
  }

  async update(ownerUid: string, id: string, payload: TUpdate): Promise<Record<string, unknown> | null> {
    const docRef = db.collection(this.collectionName).doc(id);
    const existingDoc = await docRef.get();

    if (!existingDoc.exists) {
      return null;
    }

    const existingData = existingDoc.data();
    if (!existingData || existingData.ownerUid !== ownerUid || existingData.isDeleted === true) {
      return null;
    }

    await docRef.update({
      ...payload,
      updatedAt: FieldValue.serverTimestamp(),
    });

    const updatedDoc = await docRef.get();
    return mapDoc<Record<string, unknown>>(updatedDoc.id, updatedDoc.data() ?? {});
  }

  async softDelete(ownerUid: string, id: string): Promise<boolean> {
    const docRef = db.collection(this.collectionName).doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return false;
    }

    const data = doc.data();
    if (!data || data.ownerUid !== ownerUid || data.isDeleted === true) {
      return false;
    }

    await docRef.update({
      isDeleted: true,
      deletedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return true;
  }
}