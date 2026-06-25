import { NextResponse, type NextRequest } from 'next/server';

const LOGIN_PATH = '/login';
const SESSION_COOKIE_NAMES = ['admin_token', 'admin_refresh_token'];

export function proxy(request: NextRequest) {
  const { pathname, search } = request.nextUrl;

  if (pathname === LOGIN_PATH) {
    return NextResponse.next();
  }

  const hasAdminSessionCookie = SESSION_COOKIE_NAMES.some((name) =>
    request.cookies.has(name),
  );

  if (!hasAdminSessionCookie) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = LOGIN_PATH;
    loginUrl.searchParams.set('next', `${pathname}${search}`);
    return NextResponse.redirect(loginUrl);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\..*).*)'],
};
