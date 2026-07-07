import { MessageCircle } from "lucide-react";
import { brand } from "@/config/brand";

type Props = {
  forceLight?: boolean;
  forceDark?: boolean;
  className?: string;
  alt?: string;
};

/**
 * Logo do app: ícone verde (chat) + nome ZAPIACRM.
 * Substitui a versão anterior baseada em `<img>` que quebrava porque
 * `getLogoUrl()` retornava string vazia e `brand.logoLight` era undefined.
 */
export function Logo({ className = "", alt }: Props) {
  return (
    <span
      className={`inline-flex items-center gap-2 ${className}`}
      aria-label={alt || brand.name}
    >
      <span className="size-9 md:size-10 grid place-items-center rounded-xl bg-gradient-brand text-primary-foreground shadow-[0_8px_24px_-10px_rgba(22,163,74,.6)] ring-1 ring-white/20">
        <MessageCircle className="size-5 md:size-6" strokeWidth={2.4} aria-hidden />
      </span>
      <span className="font-display font-extrabold text-base md:text-lg text-gradient-brand leading-none">
        {brand.name}
      </span>
    </span>
  );
}
