package one.nextera.nexrun.store;

import one.nextera.nexrun.store.boot.RouterBoot;
import io.javelle.core.JavelleApp;

public final class App {
  private App() {
  }

  public static void main(String[] args) {
    JavelleApp app = JavelleApp.create("NexRun Store")
        .boot(new RouterBoot());

    System.out.println(app);
  }
}
