import React from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faDiscord } from '@fortawesome/free-brands-svg-icons';
import styled from 'styled-components/macro';
import tw from 'twin.macro';

export const DISCORD_INVITE_URL = 'https://discord.gg/ykkkjwDnAD';

const StyledLink = styled.a`
    ${tw`inline-flex items-center justify-center rounded-lg px-6 py-3 no-underline font-semibold text-sm tracking-wide transition-all duration-150`};
    background: #5865f2;
    border: 1px solid #4752c4;
    color: #ffffff;

    &:hover {
        background: #4752c4;
        box-shadow: 0 0 18px rgba(88, 101, 242, 0.45);
    }

    & > svg {
        ${tw`mr-2 text-lg`};
    }
`;

interface Props {
    className?: string;
}

/**
 * Discord-branded button linking to the Touch Down Hosting community server —
 * the place to get help with login problems and everything else.
 */
const DiscordButton = ({ className }: Props) => (
    <div css={tw`flex justify-center`} className={className}>
        <StyledLink href={DISCORD_INVITE_URL} target={'_blank'} rel={'noopener noreferrer'}>
            <FontAwesomeIcon icon={faDiscord} />
            Join our Discord
        </StyledLink>
    </div>
);

export default DiscordButton;
