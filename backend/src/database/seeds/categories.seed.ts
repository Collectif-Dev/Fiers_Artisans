import { DataSource } from 'typeorm';
import { randomUUID } from 'node:crypto';

const categories = [
  {
    name: 'Bâtiment & Construction',
    slug: 'batiment-construction',
    icon_url: '🧱',
    display_order: 1,
    subcategories: [
      'Maçon gros oeuvre',
      'Maçon finitions',
      'Coffreur-bancheur',
      'Carreleur',
      'Façadier',
      'Étancheur',
      'Plâtrier',
      'Ferrailleur',
    ],
  },
  {
    name: 'Menuiserie & Ébénisterie',
    slug: 'menuiserie-ebenisterie',
    icon_url: '🪵',
    display_order: 2,
    subcategories: [
      'Menuisier bois',
      'Menuisier aluminium',
      'Ébéniste',
      'Charpentier bois',
      'Poseur de parquet',
      'Poseur de cuisine',
      'Fabricant de meubles sur mesure',
    ],
  },
  {
    name: 'Électricité',
    slug: 'electricite',
    icon_url: '⚡',
    display_order: 3,
    subcategories: [
      'Électricien bâtiment',
      'Électricien industriel',
      'Installateur solaire',
      'Domoticien',
      'Câbleur réseau',
      'Installateur vidéosurveillance',
      'Technicien maintenance électrique',
    ],
  },
  {
    name: 'Plomberie',
    slug: 'plomberie',
    icon_url: '🔧',
    display_order: 4,
    subcategories: [
      'Plombier sanitaire',
      'Plombier dépannage',
      'Installateur chauffe-eau',
      'Technicien traitement eau',
      'Installateur pompe hydraulique',
      'Déboucheur canalisation',
      'Chauffagiste',
    ],
  },
  {
    name: 'Peinture & Décoration',
    slug: 'peinture-decoration',
    icon_url: '🎨',
    display_order: 5,
    subcategories: [
      'Peintre intérieur',
      'Peintre façade',
      'Enduiseur',
      'Staffeur',
      'Décorateur intérieur',
      'Poseur papier peint',
      'Plaquiste décoratif',
    ],
  },
  {
    name: 'Architecture & Ingénierie',
    slug: 'architecture-ingenierie',
    icon_url: '🏗️',
    display_order: 6,
    subcategories: [
      'Architecte',
      'Dessinateur bâtiment',
      'Ingénieur civil',
      'Géomètre topographe',
      'Conducteur de travaux',
      'Métreur',
    ],
  },
  {
    name: 'Textile & Mode',
    slug: 'textile-mode',
    icon_url: '✂️',
    display_order: 7,
    subcategories: [
      'Tailleur homme',
      'Couturier femme',
      'Styliste modéliste',
      'Brodeur',
      'Retoucheur textile',
      'Costumier évènementiel',
    ],
  },
  {
    name: 'Métallurgie',
    slug: 'metallurgie',
    icon_url: '⚒️',
    display_order: 8,
    subcategories: [
      'Soudeur arc',
      'Soudeur inox',
      'Ferronnier d\'art',
      'Chaudronnier',
      'Forgeron',
      'Fabricant portail métallique',
    ],
  },
  {
    name: 'Fleuriste & Paysagisme',
    slug: 'fleuriste-paysagisme',
    icon_url: '🌸',
    display_order: 9,
    subcategories: [
      'Fleuriste évènementiel',
      'Jardinier',
      'Paysagiste',
      'Élagueur',
      'Poseur de gazon',
      'Entretien espaces verts',
    ],
  },
  {
    name: 'Automobile',
    slug: 'automobile',
    icon_url: '🚗',
    display_order: 10,
    subcategories: [
      'Mécanicien auto',
      'Électricien auto',
      'Tôlier',
      'Peintre automobile',
      'Diagnosticien électronique auto',
      'Technicien climatisation auto',
    ],
  },
  {
    name: 'Services créatifs',
    slug: 'services-creatifs',
    icon_url: '📸',
    display_order: 11,
    subcategories: [
      'Photographe évènementiel',
      'Vidéaste',
      'Monteur vidéo',
      'Graphiste print',
      'Illustrateur',
      'Opérateur drone',
    ],
  },
  {
    name: 'Services domestiques',
    slug: 'services-domestiques',
    icon_url: '🧹',
    display_order: 12,
    subcategories: [
      'Agent d\'entretien',
      'Femme/Homme de ménage',
      'Repassage à domicile',
      'Nounou',
      'Gardiennage résidentiel',
      'Laveur de vitres',
    ],
  },
  {
    name: 'Beauté & Bien-être',
    slug: 'beaute-bien-etre',
    icon_url: '💇',
    display_order: 13,
    subcategories: [
      'Coiffeur',
      'Coiffeur tresses',
      'Barbier',
      'Esthéticienne',
      'Maquilleuse',
      'Prothésiste ongulaire',
      'Masseuse bien-être',
    ],
  },
  {
    name: 'Restauration',
    slug: 'restauration',
    icon_url: '🍳',
    display_order: 14,
    subcategories: [
      'Cuisinier',
      'Traiteur',
      'Pâtissier',
      'Boulanger',
      'Grillardin',
      'Chef évènementiel',
      'Décorateur de gâteaux',
    ],
  },
  {
    name: 'Tech & Numérique',
    slug: 'tech-numerique',
    icon_url: '🖥️',
    display_order: 15,
    subcategories: [
      'Réparateur téléphone',
      'Technicien informatique',
      'Installateur réseau',
      'Installateur fibre optique',
      'Technicien imprimante',
      'Développeur web',
    ],
  },
  {
    name: 'Ameublement',
    slug: 'ameublement',
    icon_url: '🪑',
    display_order: 16,
    subcategories: [
      'Tapissier',
      'Matelassier',
      'Vitrier',
      'Sellier',
      'Restaurateur de meubles',
      'Poseur de rideaux et stores',
    ],
  },
];

function toSlug(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

export async function seedCategories(dataSource: DataSource): Promise<void> {
  const categoryRepo = dataSource.getRepository('categories');
  const subcategoryRepo = dataSource.getRepository('subcategories');

  for (const cat of categories) {
    const existingCat = await categoryRepo.findOne({ where: { slug: cat.slug } });
    const categoryId = existingCat?.id ?? randomUUID();

    await categoryRepo.save({
      id: categoryId,
      name: cat.name,
      slug: cat.slug,
      icon_url: cat.icon_url,
      display_order: cat.display_order,
      is_active: true,
    });

    for (const subName of cat.subcategories) {
      const subSlug = toSlug(subName);
      const existingSub = await subcategoryRepo.findOne({
        where: { slug: subSlug },
      });

      await subcategoryRepo.save({
        id: existingSub?.id ?? randomUUID(),
        category_id: categoryId,
        name: subName,
        slug: subSlug,
      });
    }
  }

  console.log('✅ Categories seeded successfully');
}
