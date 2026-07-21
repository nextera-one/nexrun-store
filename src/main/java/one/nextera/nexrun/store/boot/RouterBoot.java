package one.nextera.nexrun.store.boot;

import one.nextera.nexrun.store.layouts.MainLayout;
import one.nextera.nexrun.store.pages.HomePage;
import one.nextera.nexrun.store.pages.MysqlAppPage;
import one.nextera.nexrun.store.pages.SecurityPage;
import one.nextera.nexrun.store.pages.NotFoundPage;
import io.javelle.core.Boot;
import io.javelle.core.JavelleApp;
import io.javelle.core.JavelleBoot;

@Boot(order = 10)
public final class RouterBoot implements JavelleBoot {
  @Override
  public void boot(JavelleApp app) {
    app.route("/", HomePage.class, "MainLayout");
    app.route("/apps/nextera/mysql", MysqlAppPage.class, "MainLayout");
    app.route("/security", SecurityPage.class, "MainLayout");
    app.notFound(NotFoundPage.class);
  }
}
