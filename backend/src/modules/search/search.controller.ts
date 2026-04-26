import { Controller, Get, Query } from '@nestjs/common';
import { SearchService } from './search.service';
import { SearchArtisansDto } from './dto/search-artisans.dto';

@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get('artisans')
  searchArtisans(@Query() dto: SearchArtisansDto) {
    return this.searchService.searchArtisans(dto);
  }
}
