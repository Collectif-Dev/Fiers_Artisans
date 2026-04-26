/**
 * Chargement anticipé des variables d'environnement.
 * Ce fichier DOIT être importé en PREMIER dans main.ts,
 * AVANT l'import de AppModule, pour que process.env soit
 * peuplé au moment où les décorateurs @Module s'évaluent.
 */
import { config } from 'dotenv';
import { resolve } from 'path';

const envPath = resolve(__dirname, '../../.env');
config({ path: envPath });
