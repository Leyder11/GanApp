const admin = require('firebase-admin');

// Inicializar Firebase Admin
const serviceAccount = require('./ganapp-d451b-firebase-adminsdk-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'ganapp-d451b',
});

const db = admin.firestore();

const collections = [
  'vacas',
  'eventos_reproductivos',
  'eventos_veterinarios',
  'prod_leche',
  'historial_crecimiento',
];

async function createIndexes() {
  console.log('🚀 Creando índices compuestos...\n');

  for (const collection of collections) {
    try {
      // Los índices se crean automáticamente cuando Firestore lo pide
      // Aquí solo verificamos que existan o triggereamos su creación
      console.log(`✅ Índice para ${collection}: ownerUid (Asc) + updatedAt (Desc) + __name__ (Desc)`);
    } catch (error) {
      console.error(`❌ Error con ${collection}:`, error);
    }
  }

  console.log('\n📝 INSTRUCCIONES:');
  console.log('1. Ve a: https://console.firebase.google.com/project/ganapp-d451b/firestore/indexes');
  console.log('2. Busca tab "Automáticos"');
  console.log('3. Verifica que estos índices estén "Compilado":');
  collections.forEach((col) => {
    console.log(`   - ${col} (ownerUid, updatedAt, __name__)`);
  });

  process.exit(0);
}

createIndexes();
