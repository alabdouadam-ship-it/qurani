/** Invalidates work started before a newer request or an unmount. */
export class LatestRequest {
  private revision = 0;

  begin(): () => boolean {
    const revision = ++this.revision;
    return () => revision === this.revision;
  }

  invalidate(): void {
    ++this.revision;
  }
}
