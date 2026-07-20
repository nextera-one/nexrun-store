package one.nextera.nexrun.store.pages;

import io.javelle.core.Component;
import io.javelle.core.Template;

@Component("not-found-page")
public final class NotFoundPage {
  @Template("NotFoundPage.jvl")
  public String view() {
    return "";
  }
}
