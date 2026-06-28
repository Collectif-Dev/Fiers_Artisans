import { Controller, Get, Query } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { SearchService } from './search.service';
import { SearchArtisansDto } from './dto/search-artisans.dto';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get('artisans')
  @Throttle({ default: { limit: 40, ttl: 60 * 1000 } })
  searchArtisans(@Query() dto: SearchArtisansDto) {
    return this.searchService.searchArtisans(dto);
  }
}
