import * as React from 'react';
import { useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link, NavLink } from 'react-router-dom';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faCogs, faLayerGroup, faPalette, faSignOutAlt } from '@fortawesome/free-solid-svg-icons';
import { useStoreState } from 'easy-peasy';
import { ApplicationStore } from '@/state';
import SearchContainer from '@/components/dashboard/search/SearchContainer';
import tw from 'twin.macro';
import styled from 'styled-components/macro';
import http from '@/api/http';
import SpinnerOverlay from '@/components/elements/SpinnerOverlay';
import Tooltip from '@/components/elements/tooltip/Tooltip';
import Avatar from '@/components/Avatar';
import BrandLogo from '@/components/touchdown/BrandLogo';
import VersionBadge from '@/components/touchdown/VersionBadge';
import { applyTheme, builtInThemes, fetchThemes, getActiveThemeId, TouchDownTheme } from '@/touchdown/themes';

const RightNavigation = styled.div`
    & > a,
    & > button,
    & > .navigation-link {
        ${tw`flex items-center h-full no-underline px-6 cursor-pointer transition-all duration-150`};
        color: var(--tdh-text-muted);

        &:active,
        &:hover {
            color: #ffffff;
            background: rgba(255, 255, 255, 0.04);
        }

        &:active,
        &:hover,
        &.active {
            box-shadow: inset 0 -2px var(--tdh-brand-500);
            color: var(--tdh-brand-400);
        }
    }
`;

const ThemeMenu = styled.div`
    ${tw`fixed rounded-lg overflow-hidden`};
    z-index: 9980;
    top: 3.75rem;
    right: 1rem;
    min-width: 14rem;
    background: var(--tdh-surface-strong);
    border: 1px solid var(--tdh-surface-border);
    backdrop-filter: blur(20px) saturate(160%);
    -webkit-backdrop-filter: blur(20px) saturate(160%);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);

    & > button {
        ${tw`flex items-center w-full text-left px-4 py-3 text-sm transition-colors duration-150`};
        color: var(--tdh-text);

        &:hover {
            background: rgba(255, 255, 255, 0.06);
        }

        &.active {
            color: var(--tdh-brand-400);
        }
    }
`;

const Swatch = styled.span<{ $color: string }>`
    ${tw`inline-block w-4 h-4 rounded-full mr-3 flex-shrink-0`};
    background: ${(props) => props.$color};
    border: 1px solid rgba(255, 255, 255, 0.25);
`;

export default () => {
    const rootAdmin = useStoreState((state: ApplicationStore) => state.user.data!.rootAdmin);
    const [isLoggingOut, setIsLoggingOut] = useState(false);
    const [themes, setThemes] = useState<TouchDownTheme[]>(builtInThemes);
    const [themeMenuOpen, setThemeMenuOpen] = useState(false);
    const [activeTheme, setActiveTheme] = useState(getActiveThemeId());
    const menuRef = useRef<HTMLDivElement>(null);
    const buttonRef = useRef<HTMLButtonElement>(null);

    useEffect(() => {
        fetchThemes().then(setThemes);
    }, []);

    useEffect(() => {
        if (!themeMenuOpen) return;

        const listener = (e: MouseEvent) => {
            const target = e.target as Node;
            // Ignore the toggle button itself: closing here on mousedown would
            // let its own onClick immediately reopen the menu.
            if (buttonRef.current?.contains(target)) return;
            if (menuRef.current && !menuRef.current.contains(target)) {
                setThemeMenuOpen(false);
            }
        };

        const onEscape = (e: KeyboardEvent) => {
            if (e.key === 'Escape') setThemeMenuOpen(false);
        };

        document.addEventListener('mousedown', listener);
        document.addEventListener('keydown', onEscape);
        return () => {
            document.removeEventListener('mousedown', listener);
            document.removeEventListener('keydown', onEscape);
        };
    }, [themeMenuOpen]);

    const onSelectTheme = (theme: TouchDownTheme) => {
        applyTheme(theme);
        setActiveTheme(theme.id);
        setThemeMenuOpen(false);
    };

    const onTriggerLogout = () => {
        setIsLoggingOut(true);
        http.post('/auth/logout').finally(() => {
            // @ts-expect-error this is valid
            window.location = '/';
        });
    };

    return (
        <div className={'w-full tdh-glass-strong shadow-md overflow-x-auto overflow-y-visible'}>
            <SpinnerOverlay visible={isLoggingOut} />
            <div className={'mx-auto w-full flex items-center h-[3.5rem] max-w-[1200px]'}>
                <div id={'logo'} className={'flex-1 flex items-center'}>
                    <Link to={'/'} className={'flex items-center pl-4 no-underline'}>
                        <BrandLogo variant={'nav'} />
                    </Link>
                    <VersionBadge />
                </div>
                <RightNavigation className={'flex h-full items-center justify-center relative'}>
                    <SearchContainer />
                    <Tooltip placement={'bottom'} content={'Dashboard'}>
                        <NavLink to={'/'} exact>
                            <FontAwesomeIcon icon={faLayerGroup} />
                        </NavLink>
                    </Tooltip>
                    <Tooltip placement={'bottom'} content={'Themes'}>
                        <button ref={buttonRef} onClick={() => setThemeMenuOpen((s) => !s)}>
                            <FontAwesomeIcon icon={faPalette} />
                        </button>
                    </Tooltip>
                    {/*
                     * Rendered through a portal: the navigation bar uses
                     * backdrop-filter, which makes it the containing block for
                     * position:fixed children, and its overflow-x:auto clips
                     * anything drawn below it. Inside the bar this menu mounted
                     * but was clipped to nothing.
                     */}
                    {themeMenuOpen &&
                        createPortal(
                            <ThemeMenu ref={menuRef}>
                                {themes.map((theme) => (
                                    <button
                                        key={theme.id}
                                        className={theme.id === activeTheme ? 'active' : undefined}
                                        onClick={() => onSelectTheme(theme)}
                                    >
                                        <Swatch $color={theme.colors.brand['500']} />
                                        {theme.name}
                                    </button>
                                ))}
                            </ThemeMenu>,
                            document.body
                        )}
                    {rootAdmin && (
                        <Tooltip placement={'bottom'} content={'Admin'}>
                            <a href={'/admin'} rel={'noreferrer'}>
                                <FontAwesomeIcon icon={faCogs} />
                            </a>
                        </Tooltip>
                    )}
                    <Tooltip placement={'bottom'} content={'Account Settings'}>
                        <NavLink to={'/account'}>
                            <span className={'flex items-center w-5 h-5'}>
                                <Avatar.User />
                            </span>
                        </NavLink>
                    </Tooltip>
                    <Tooltip placement={'bottom'} content={'Sign Out'}>
                        <button onClick={onTriggerLogout}>
                            <FontAwesomeIcon icon={faSignOutAlt} />
                        </button>
                    </Tooltip>
                </RightNavigation>
            </div>
        </div>
    );
};
