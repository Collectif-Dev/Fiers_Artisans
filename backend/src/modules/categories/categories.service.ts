import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Category } from './entities/category.entity';
import { Subcategory } from './entities/subcategory.entity';
import { seedCategories } from '../../database/seeds/categories.seed';

@Injectable()
export class CategoriesService implements OnModuleInit {
  private readonly logger = new Logger(CategoriesService.name);
  private ensureSeedPromise: Promise<void> | null = null;

  constructor(
    @InjectRepository(Category)
    private readonly categoryRepository: Repository<Category>,
    @InjectRepository(Subcategory)
    private readonly subcategoryRepository: Repository<Subcategory>,
    private readonly dataSource: DataSource,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.ensureDefaultTaxonomy();
  }

  private async ensureDefaultTaxonomy(): Promise<void> {
    if (this.ensureSeedPromise) {
      await this.ensureSeedPromise;
      return;
    }

    this.ensureSeedPromise = (async () => {
      const activeCategoriesCount = await this.categoryRepository.count({
        where: { is_active: true },
      });

      if (activeCategoriesCount > 0) {
        return;
      }

      this.logger.warn(
        'No active categories found. Seeding default taxonomy...',
      );
      await seedCategories(this.dataSource);
      this.logger.log('Default taxonomy seeded successfully.');
    })().finally(() => {
      this.ensureSeedPromise = null;
    });

    await this.ensureSeedPromise;
  }

  async findAll(): Promise<Category[]> {
    await this.ensureDefaultTaxonomy();

    return this.categoryRepository.find({
      where: { is_active: true },
      relations: ['subcategories'],
      order: { display_order: 'ASC' },
    });
  }

  async findBySlug(slug: string): Promise<Category | null> {
    await this.ensureDefaultTaxonomy();

    return this.categoryRepository.findOne({
      where: { slug, is_active: true },
      relations: ['subcategories'],
    });
  }
}
