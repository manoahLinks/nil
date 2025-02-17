import { combine, sample } from "effector";
import { interval } from "patronum";
import { $endpoint } from "../account-connector/model";
import { loadedPlaygroundPage } from "../code/model";
import { playgroundRoute, playgroundWithHashRoute } from "../routing/routes/playgroundRoute";
import { $isPageVisible, $rpcIsHealthy, checkRpcHealthFx, pageVisibilityChanged } from "./model";

$isPageVisible.on(pageVisibilityChanged, (_, isVisible) => isVisible);
document.addEventListener("visibilitychange", () => {
  pageVisibilityChanged(document.visibilityState === "visible");
});

const { tick } = interval({
  timeout: 1000 * 10,
  start: loadedPlaygroundPage,
  leading: true,
});

sample({
  clock: tick,
  target: checkRpcHealthFx,
  source: $endpoint,
  filter: combine(
    $isPageVisible,
    playgroundRoute.$isOpened,
    playgroundWithHashRoute.$isOpened,
    (isVisible, isPlaygroundOpened, isPlaygroundWithHashOpened) =>
      isVisible && (isPlaygroundOpened || isPlaygroundWithHashOpened),
  ),
});

sample({
  clock: $endpoint,
  target: checkRpcHealthFx,
});

$rpcIsHealthy.on(checkRpcHealthFx.doneData, (_, data) => data);
