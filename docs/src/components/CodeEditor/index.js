import React from 'react';
import Editor from '@monaco-editor/react';
import { useColorMode } from '@docusaurus/theme-common';
import styles from "./styles.module.css";

export default function CodeEditor({defaultValue}) {
  
  const { colorMode } = useColorMode();
  const theme = (colorMode === "dark") ? "vs-dark" : "light";
  
  return (
    <div className={styles.editorContainer}>
     <Editor
      height="90vh"
      defaultLanguage="sol"
      theme={theme}
      defaultValue={defaultValue}
    />
    </div>
  );
}