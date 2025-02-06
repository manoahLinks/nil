import type { ReactNode } from "react";
import {
  AssistantRuntimeProvider,
  useLocalRuntime,
  type ChatModelAdapter,
} from "@assistant-ui/react";
import { useCallback, useEffect, useMemo, useState } from "react";

import { useGoogleReCaptcha } from "react-google-recaptcha-v3";

const CustomModelAdapter: (string, Function) => ChatModelAdapter = (
  token,
  handleReCaptchaVerify,
) => ({
  async *run({ messages, abortSignal }) {
    yield { content: [{ type: "text", text: "Thinking..." }] };
    
    const messagesToSend = messages.map((m) => ({
      role: m.role,
      content: m.content
        .filter((c) => c.type === "text")
        .map((c) => c.text)
        .join(" "),
    }));

    const response = await fetch("https://docs.nil.foundation/bot/api/chat", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messages: messagesToSend,
        token: token,
      }),
      signal: abortSignal,
    });

    handleReCaptchaVerify();

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    if (!response.body) {
      throw new Error('No response body received');
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let accumulatedText = '';
    let isFirstChunk = true;

    try {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        const newText = decoder.decode(value, { stream: true });
        buffer += newText;
            if (isFirstChunk) {
              accumulatedText = newText;
              isFirstChunk = false;
            } else {
              accumulatedText += newText;
            }
            yield { content: [{ type: "text", text: accumulatedText }] };
      }
    } finally {
      reader.releaseLock();
    }
  },
});

export function CustomRuntimeProvider({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  const [token, tokenSetter] = useState<string | null>(null);

  const { executeRecaptcha } = useGoogleReCaptcha();

  const handleReCaptchaVerify = useCallback(async () => {
    if (!executeRecaptcha) {
      return;
    }

    const t = await executeRecaptcha();
    tokenSetter(t);
  }, [executeRecaptcha]);

  useEffect(() => {
    handleReCaptchaVerify();
  }, [handleReCaptchaVerify]);

  const adapter = useMemo(() => {
    return CustomModelAdapter(token, handleReCaptchaVerify);
  }, [token]);
  const runtime = useLocalRuntime(adapter);

  return <AssistantRuntimeProvider runtime={runtime}>{children}</AssistantRuntimeProvider>;
}
